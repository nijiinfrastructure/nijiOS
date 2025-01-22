module TwitterSpacesCore

using Base.Events
using Dates
using HTTP
using JSON3
using ..TwitterScraper
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes
using ..TwitterSpacesChatClient
using ..TwitterSpacesJanusClient

"""
    SpaceConfig

Configuration for a space
"""
struct SpaceConfig
    mode::String  # "BROADCAST" | "LISTEN" | "INTERACTIVE"
    title::Union{String,Nothing}
    description::Union{String,Nothing}
    languages::Union{Vector{String},Nothing}
    debug::Bool
end

"""
    Space

Manages the creation of a new Space (Broadcast Host):
1) Created the broadcast on Periscope
2) Set up Janus WebRTC for audio
3) Optionally create a chat client for interactive mode
4) Allows management of speakers, audio push etc.
"""
mutable struct Space <: AbstractEventEmitter
    scraper::Scraper
    debug::Bool
    logger::Logger
    
    janus_client::Union{JanusClient,Nothing}
    chat_client::Union{ChatClient,Nothing}
    
    auth_token::Union{String,Nothing}
    broadcast_info::Union{BroadcastCreated,Nothing}
    is_initialized::Bool
    
    plugins::Set{PluginRegistration}
    speakers::Dict{String,SpeakerInfo}
    
    function Space(scraper::Scraper; debug::Bool=false)
        new(scraper, debug, Logger(debug),
            nothing, nothing, nothing, nothing, false,
            Set{PluginRegistration}(), Dict{String,SpeakerInfo}())
    end
end

"""
    use(space::Space, plugin::Plugin, config::Union{Dict,Nothing}=nothing)::Space

Registers a plugin and calls its onAttach(...).
init(...) is called as soon as initialization is complete.
"""
function use(space::Space, plugin::Plugin, config::Union{Dict,Nothing}=nothing)::Space
    registration = PluginRegistration(plugin, config)
    push!(space.plugins, registration)
    
    space.logger.debug("[Space] Plugin added =>", plugin.name)
    if !isnothing(plugin.on_attach)
        plugin.on_attach(space=space, plugin_config=config)
    end
    
    # If space is initialized, call plugin.init(...)
    if space.is_initialized && !isnothing(plugin.init)
        plugin.init(space=space, plugin_config=config)
        # If Janus is also ready, call plugin.onJanusReady(...)
        if !isnothing(space.janus_client) && !isnothing(plugin.on_janus_ready)
            plugin.on_janus_ready(space.janus_client)
        end
    end
    
    return space
end

"""
    initialize(space::Space, config::SpaceConfig)::BroadcastCreated

Main entry point for creating and initializing the space broadcast.
"""
function initialize(space::Space, config::SpaceConfig)::BroadcastCreated
    space.logger.debug("[Space] Initializing...")
    
   #1) Get Periscope Cookie + Region
    cookie = get_periscope_cookie(space.scraper)
    region = get_region()
    space.logger.debug("[Space] Got region =>", region)
    
    # 2) create broadcast
    space.logger.debug("[Space] Creating broadcast...")
    broadcast = create_broadcast(
        description=config.description,
        languages=config.languages,
        cookie=cookie,
        region=region
    )
    space.broadcast_info = broadcast
    
    # 3) Token authorize
    space.logger.debug("[Space] Authorizing token...")
    space.auth_token = authorize_token(cookie)
    
    # 4) Get TURN servers
    space.logger.debug("[Space] Getting turn servers...")
    turn_servers = get_turn_servers(cookie)
    
    # 5) Initialize Janus for hosting
    space.janus_client = JanusClient(
        webrtc_url=broadcast.webrtc_gw_url,
        room_id=broadcast.room_id,
        credential=broadcast.credential,
        user_id=broadcast.broadcast.user_id,
        stream_name=broadcast.stream_name,
        turn_servers=turn_servers,
        logger=space.logger
    )
    initialize(space.janus_client)
    
    # Forward PCM from Janus to plugin.onAudioData
    on(space.janus_client, :audioDataFromSpeaker) do data
        space.logger.debug("[Space] Received PCM from speaker =>", data.user_id)
        handle_audio_data(space, data)
    end
    
    # Update speaker info after subscribe
    on(space.janus_client, :subscribedSpeaker) do evt
        speaker = get(space.speakers, evt.user_id, nothing)
        if isnothing(speaker)
            space.logger.debug(
                "[Space] subscribedSpeaker => no speaker found",
                evt.user_id
            )
            return
        end
        speaker.janus_participant_id = evt.feed_id
        space.logger.debug(
            "[Space] updated speaker => userId=$(evt.user_id), feedId=$(evt.feed_id)"
        )
    end
    
    ##6) Publish broadcast
    space.logger.debug("[Space] Publishing broadcast...")
    publish_broadcast(
        title=config.title || "",
        broadcast=broadcast,
        cookie=cookie,
        janus_session_id=get_session_id(space.janus_client),
        janus_handle_id=get_handle_id(space.janus_client),
        janus_publisher_id=get_publisher_id(space.janus_client)
    )
    
    # 7) If interactive => Set up ChatClient
    if config.mode == "INTERACTIVE"
        space.logger.debug("[Space] Connecting chat...")
        space.chat_client = ChatClient(
            space_id=broadcast.room_id,
            access_token=broadcast.access_token,
            endpoint=broadcast.endpoint,
            logger=space.logger
        )
        connect(space.chat_client)
        setup_chat_events(space)
    end
    
    space.logger.info(
        "[Space] Initialized =>",
        replace(broadcast.share_url, "broadcasts" => "spaces")
    )
    space.is_initialized = true
    
    # Call plugin.init(...) and onJanusReady(...) for all plugins
    for registration in space.plugins
        if !isnothing(registration.plugin.init)
            registration.plugin.init(space=space, plugin_config=registration.config)
        end
        if !isnothing(registration.plugin.on_janus_ready)
            registration.plugin.on_janus_ready(space.janus_client)
        end
    end
    
    space.logger.debug("[Space] All plugins initialized")
    return broadcast
end

"""
    react_with_emoji(space::Space, emoji::String)::Nothing

Sends an emoji reaction via chat (in interactive mode only).
"""
function react_with_emoji(space::Space, emoji::String)::Nothing
    if !isnothing(space.chat_client)
        react_with_emoji(space.chat_client, emoji)
    end
    nothing
end

"""
    approve_speaker(space::Space, user_id::String, session_uuid::String)::Nothing

Approves a speaker request and subscribes to its audio via Janus.
"""
function approve_speaker(space::Space, user_id::String, session_uuid::String)::Nothing
    if !space.is_initialized || isnothing(space.broadcast_info)
        throw(ErrorException("[Space] Not initialized or missing broadcastInfo"))
    end
    if isnothing(space.auth_token)
        throw(ErrorException("[Space] No auth token available"))
    end

    # Save to local speaker map
    space.speakers[user_id] = SpeakerInfo(user_id, session_uuid)

   #1) Go to Twitter's /request/approve
    call_approve_endpoint(
        space,
        space.broadcast_info,
        space.auth_token,
        user_id,
        session_uuid
    )

    #2) Subscribe to audio in Janus
    if !isnothing(space.janus_client)
        subscribe_speaker(space.janus_client, user_id)
    end
    
    nothing
end

"""
    finalize_space(space::Space)::Nothing

Ends the space properly: destroys the Janus room, ends the broadcast, etc.
"""
function finalize_space(space::Space)::Nothing
    space.logger.info("[Space] finalizeSpace => stopping broadcast gracefully")

    tasks = []

    if !isnothing(space.janus_client)
        push!(tasks, @async try
            destroy_room(space.janus_client)
        catch err
            space.logger.error("[Space] destroyRoom error =>", err)
        end)
    end

    if !isnothing(space.broadcast_info)
        push!(tasks, @async try
            end_audiospace(space, Dict(
                "broadcastId" => space.broadcast_info.room_id,
                "chatToken" => space.broadcast_info.access_token
            ))
        catch err
            space.logger.error("[Space] endAudiospace error =>", err)
        end)
    end

    if !isnothing(space.janus_client)
        push!(tasks, @async try
            leave_room(space.janus_client)
        catch err
            space.logger.error("[Space] leaveRoom error =>", err)
        end)
    end

    wait.(tasks)
    space.logger.info("[Space] finalizeSpace => done.")
    nothing
end

"""
    mute_host(space::Space)::Nothing

Mutes the host (itself). For the host, session_uuid is empty.
"""
function mute_host(space::Space)::Nothing
    if isnothing(space.auth_token)
        throw(ErrorException("[Space] No auth token available"))
    end
    if isnothing(space.broadcast_info)
        throw(ErrorException("[Space] No broadcastInfo"))
    end

    mute_speaker(
        broadcast_id=space.broadcast_info.room_id,
        session_uuid="",  # host => leer
        chat_token=space.broadcast_info.access_token,
        auth_token=space.auth_token
    )
    space.logger.info("[Space] Host muted successfully.")
    nothing
end

"""
    unmute_host(space::Space)::Nothing

Unmutes the host.
"""
function unmute_host(space::Space)::Nothing
    if isnothing(space.auth_token)
        throw(ErrorException("[Space] No auth token"))
    end
    if isnothing(space.broadcast_info)
        throw(ErrorException("[Space] No broadcastInfo"))
    end

    unmute_speaker(
        broadcast_id=space.broadcast_info.room_id,
        session_uuid="",
        chat_token=space.broadcast_info.access_token,
        auth_token=space.auth_token
    )
    space.logger.info("[Space] Host unmuted successfully.")
    nothing
end

"""
    stop(space::Space)::Nothing

Completely stops the broadcast, runs finalize_space() and cleans up plugins.
"""
function stop(space::Space)::Nothing
    space.logger.info("[Space] Stopping...")

    try
        finalize_space(space)
    catch err
        space.logger.error("[Space] finalizeBroadcast error =>", err)
    end

    # Disconnect chat if available
    if !isnothing(space.chat_client)
        disconnect(space.chat_client)
        space.chat_client = nothing
    end

    # Stop Janus if active
    if !isnothing(space.janus_client)
        stop(space.janus_client)
        space.janus_client = nothing
    end

    # Clean up all plugins
    for registration in space.plugins
        if !isnothing(registration.plugin.cleanup)
            registration.plugin.cleanup()
        end
    end
    empty!(space.plugins)

    space.is_initialized = false
    nothing
end

export Space, SpaceConfig, use, initialize, react_with_emoji, approve_speaker, finalize_space, 
       mute_host, unmute_host, stop

end # module 