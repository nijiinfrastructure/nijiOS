module TwitterSpacesParticipant

using Base.Events
using ..TwitterSpacesLogger
using ..TwitterSpacesChatClient
using ..TwitterSpacesJanusClient
using ..TwitterScraper
using ..TwitterSpacesTypes
using ..TwitterSpacesUtils

"""
    SpaceParticipantConfig

Configuration for a space participant.
"""
struct SpaceParticipantConfig
    space_id::String
    debug::Bool
end

"""
    SpaceParticipant

Manages joining an existing space in listener mode,
and optionally becoming a speaker via WebRTC (Janus).
"""
mutable struct SpaceParticipant <: AbstractEventEmitter
    space_id::String
    debug::Bool
    logger::Logger
    
    auth_token::Union{String,Nothing}
    chat_token::Union{String,Nothing}
    session_uuid::Union{String,Nothing}
    
    janus_client::Union{JanusClient,Nothing}
    chat_client::Union{ChatClient,Nothing}
    
    plugins::Set{PluginRegistration}
    
    function SpaceParticipant(config::SpaceParticipantConfig)
        new(config.space_id, config.debug, Logger(config.debug),
            nothing, nothing, nothing, nothing, nothing,
            Set{PluginRegistration}())
    end
end

"""
    use(participant::SpaceParticipant, plugin::Plugin, 
        config::Union{Dict,Nothing}=nothing)::SpaceParticipant

Registers a plugin for this participant.
"""
function use(participant::SpaceParticipant, plugin::Plugin, 
             config::Union{Dict,Nothing}=nothing)::SpaceParticipant
    registration = PluginRegistration(plugin, config)
    push!(participant.plugins, registration)
    
    participant.logger.debug("[SpaceParticipant] Plugin added =>", plugin.name)
    if !isnothing(plugin.on_attach)
        plugin.on_attach(participant=participant, plugin_config=config)
    end
    
    return participant
end

"""
    join(participant::SpaceParticipant)::Nothing

Join a Space as a listener:
1) Get chat tokens
2) Connect ChatClient
3) Initialize plugins
"""
function join(participant::SpaceParticipant)::Nothing
    participant.logger.debug("[SpaceParticipant] Joining space...")
    
    # 1) Get chat tokens
    result = access_chat(participant.space_id)
    participant.chat_token = result.access_token
    
    # 2) Connect ChatClient
    participant.chat_client = ChatClient(
        space_id=participant.space_id,
        access_token=participant.chat_token,
        endpoint=result.endpoint,
        logger=participant.logger
    )
    connect(participant.chat_client)
    setup_common_chat_events(participant)
    
    # 3) Initialize plugins
    for registration in participant.plugins
        if !isnothing(registration.plugin.init)
            registration.plugin.init(
                participant=participant,
                plugin_config=registration.config
            )
        end
    end
    
    participant.logger.info("[SpaceParticipant] Joined space successfully")
    nothing
end

"""
    request_to_speak(participant::SpaceParticipant)::Nothing

Sends a speaker request to the host.
"""
function request_to_speak(participant::SpaceParticipant)::Nothing
    if isnothing(participant.auth_token) || isnothing(participant.chat_token)
        throw(ErrorException("[SpaceParticipant] Missing authToken or chatToken"))
    end
    
    # 1) Send speaker request
    result = submit_speaker_request(
        broadcast_id=participant.space_id,
        chat_token=participant.chat_token,
        auth_token=participant.auth_token
    )
    participant.session_uuid = result.session_uuid
    participant.logger.info("[SpaceParticipant] Speaker request sent successfully")
    nothing
end

"""
    cancel_request(participant::SpaceParticipant)::Nothing

Bricht eine ausstehende Sprecheranfrage ab.
"""
function cancel_request(participant::SpaceParticipant)::Nothing
    if isnothing(participant.auth_token) || isnothing(participant.chat_token)
        throw(ErrorException("[SpaceParticipant] Missing authToken or chatToken"))
    end
    if isnothing(participant.session_uuid)
        throw(ErrorException("[SpaceParticipant] No sessionUUID; did you request to speak?"))
    end
    
    cancel_speaker_request(
        broadcast_id=participant.space_id,
        session_uuid=participant.session_uuid,
        chat_token=participant.chat_token,
        auth_token=participant.auth_token
    )
    participant.logger.info("[SpaceParticipant] Speaker request cancelled")
    nothing
end

"""
    mute_self(participant::SpaceParticipant)::Nothing

Mutes yourself as a speaker.
"""
function mute_self(participant::SpaceParticipant)::Nothing
    if isnothing(participant.auth_token) || isnothing(participant.chat_token)
        throw(ErrorException("[SpaceParticipant] Missing authToken or chatToken"))
    end
    if isnothing(participant.session_uuid)
        throw(ErrorException("[SpaceParticipant] No sessionUUID; are you a speaker?"))
    end
    
    mute_speaker(
        broadcast_id=participant.space_id,
        session_uuid=participant.session_uuid,
        chat_token=participant.chat_token,
        auth_token=participant.auth_token
    )
    participant.logger.info("[SpaceParticipant] Successfully muted self")
    nothing
end

"""
    unmute_self(participant::SpaceParticipant)::Nothing

Unmutes yourself as a speaker.
"""
function unmute_self(participant::SpaceParticipant)::Nothing
    if isnothing(participant.auth_token) || isnothing(participant.chat_token)
        throw(ErrorException("[SpaceParticipant] Missing authToken or chatToken"))
    end
    if isnothing(participant.session_uuid)
        throw(ErrorException("[SpaceParticipant] No sessionUUID; are you a speaker?"))
    end
    
    unmute_speaker(
        broadcast_id=participant.space_id,
        session_uuid=participant.session_uuid,
        chat_token=participant.chat_token,
        auth_token=participant.auth_token
    )
    participant.logger.info("[SpaceParticipant] Successfully unmuted self")
    nothing
end

"""
    leave(participant::SpaceParticipant)::Nothing

Leave the space and clear all resources.
"""
function leave(participant::SpaceParticipant)::Nothing
    participant.logger.info("[SpaceParticipant] Leaving space...")
    
    # CDisconnect chat if connected
    if !isnothing(participant.chat_client)
        disconnect(participant.chat_client)
        participant.chat_client = nothing
    end
    
    # Stop Janus if active
    if !isnothing(participant.janus_client)
        stop(participant.janus_client)
        participant.janus_client = nothing
    end
    
    # clean up all plugins
    for registration in participant.plugins
        if !isnothing(registration.plugin.cleanup)
            registration.plugin.cleanup()
        end
    end
    empty!(participant.plugins)
    
    participant.logger.info("[SpaceParticipant] Left space successfully")
    nothing
end

export SpaceParticipant, SpaceParticipantConfig,
       use, join, request_to_speak, cancel_request,
       mute_self, unmute_self, leave

end # module 