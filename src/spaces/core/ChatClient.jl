module TwitterSpacesChatClient

using Base.Events
using WebSockets
using JSON3
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes

"""
    ChatClientConfig

Configuration for ChatClient.
"""
struct ChatClientConfig
    space_id::String      # Space ID (z.B. "1vOGwAbcdE...")
    access_token::String  # Token from accessChat or live_video_stream/status
    endpoint::String      # Chat-Server Endpoint
    logger::Logger        # Logger Instance
end

"""
    ChatClient

Manages the WebSocket connection to the Twitter/Periscope Chat API
"""
mutable struct ChatClient <: AbstractEventEmitter
    config::ChatClientConfig
    ws::Union{WebSocket,Nothing}
    connected::Bool
    
    function ChatClient(config::ChatClientConfig)
        new(config, nothing, false)
    end
end

"""
    connect(client::ChatClient)::Nothing

Connect to the chat server
"""
function connect(client::ChatClient)::Nothing
    ws_url = replace(
        "$(client.config.endpoint)/chatapi/v1/chatnow",
        "https://" => "wss://"
    )
    client.config.logger.info("[ChatClient] Connecting => $ws_url")
    
    WebSockets.open(ws_url; headers=Dict(
        "Origin" => "https://x.com",
        "User-Agent" => "Mozilla/5.0"
    )) do ws
        client.ws = ws
        setup_handlers(client)
    end
    
    nothing
end

"""
    setup_handlers(client::ChatClient)::Nothing

Create WebSocket event handlers (open, message, close, error)
"""
function setup_handlers(client::ChatClient)::Nothing
    if isnothing(client.ws)
        throw(ErrorException("[ChatClient] No WebSocket instance available"))
    end
    
    # Open Handler
    WebSockets.on_open(client.ws) do ws
        client.config.logger.info("[ChatClient] Connected")
        client.connected = true
        send_auth_and_join(client)
    end
    
    # Message Handler
    WebSockets.on_message(client.ws) do ws, data
        handle_message(client, String(data))
    end
    
    # Close Handler
    WebSockets.on_close(client.ws) do ws
        client.config.logger.info("[ChatClient] Closed")
        client.connected = false
        emit(client, :disconnected)
    end
    
    # Error Handler
    WebSockets.on_error(client.ws) do ws, err
        client.config.logger.error("[ChatClient] Error => $err")
        throw(err)
    end
    
    nothing
end

"""
    send_auth_and_join(client::ChatClient)::Nothing

Send authentication and join message.
"""
function send_auth_and_join(client::ChatClient)::Nothing
    if isnothing(client.ws) return nothing end
    
    # 1) Send authentication
    WebSockets.send(client.ws, JSON3.write(Dict(
        "payload" => JSON3.write(Dict(
            "access_token" => client.config.access_token
        )),
        "kind" => 3
    )))
    
    # 2) Send join message
    WebSockets.send(client.ws, JSON3.write(Dict(
        "payload" => JSON3.write(Dict(
            "body" => JSON3.write(Dict(
                "room" => client.config.space_id
            )),
            "kind" => 1
        )),
        "kind" => 2
    )))
    
    nothing
end

"""
    react_with_emoji(client::ChatClient, emoji::String)::Nothing

Send emoji reaction to chat server
"""
function react_with_emoji(client::ChatClient, emoji::String)::Nothing
    if isnothing(client.ws) || !client.connected
        client.config.logger.warn(
            "[ChatClient] Not connected or WebSocket missing; ignoring reactWithEmoji."
        )
        return nothing
    end
    
    payload = JSON3.write(Dict(
        "body" => JSON3.write(Dict(
            "body" => emoji,
            "type" => 2,
            "v" => 2
        )),
        "kind" => 1,
        "payload" => JSON3.write(Dict(
            "room" => client.config.space_id,
            "body" => JSON3.write(Dict(
                "body" => emoji,
                "type" => 2,
                "v" => 2
            ))
        )),
        "type" => 2
    ))
    
    WebSockets.send(client.ws, payload)
    nothing
end

"""
    handle_message(client::ChatClient, raw::String)::Nothing

Processes incoming WebSocket messages.
"""
function handle_message(client::ChatClient, raw::String)::Nothing
    msg = safe_json(raw)
    isnothing(msg) && return nothing
    
    haskey(msg, :payload) || return nothing
    payload = safe_json(msg.payload)
    isnothing(payload) && return nothing
    
    haskey(payload, :body) || return nothing
    body = safe_json(payload.body)
    isnothing(body) && return nothing
    
    # 1) Speaker Request
    if get(body, :guestBroadcastingEvent, nothing) == 1
        emit(client, :speakerRequest, Dict(
            "userId" => body.guestRemoteID,
            "username" => body.guestUsername,
            "displayName" => get(get(payload, :sender, Dict()), :display_name, body.guestUsername),
            "sessionUUID" => body.sessionUUID
        ))
    end
    
    # 2) Occupancy Update
    if isa(get(body, :occupancy, nothing), Number)
        emit(client, :occupancyUpdate, Dict(
            "occupancy" => body.occupancy,
            "totalParticipants" => get(body, :total_participants, 0)
        ))
    end
    
    # 3) Mute/Unmute Events
    if get(body, :guestBroadcastingEvent, nothing) == 16
        emit(client, :muteStateChanged, Dict(
            "userId" => body.guestRemoteID,
            "muted" => true
        ))
    end
    if get(body, :guestBroadcastingEvent, nothing) == 17
        emit(client, :muteStateChanged, Dict(
            "userId" => body.guestRemoteID,
            "muted" => false
        ))
    end
    
    # 4) New Speaker Accepted
    if get(body, :guestBroadcastingEvent, nothing) == 12
        emit(client, :newSpeakerAccepted, Dict(
            "userId" => body.guestRemoteID,
            "username" => body.guestUsername,
            "sessionUUID" => body.sessionUUID
        ))
    end
    
    # 5) Reaction
    if get(body, :type, nothing) == 2
        client.config.logger.debug("[ChatClient] Emitting guestReaction =>", body)
        emit(client, :guestReaction, Dict(
            "displayName" => body.displayName,
            "emoji" => body.body
        ))
    end
    
    nothing
end

"""
    disconnect(client::ChatClient)::Nothing

Close WebSocket connection
"""
function disconnect(client::ChatClient)::Nothing
    if !isnothing(client.ws)
        client.config.logger.info("[ChatClient] Disconnecting...")
        WebSockets.close(client.ws)
        client.ws = nothing
        client.connected = false
    end
    nothing
end

"""
    safe_json(text::String)::Union{Any,Nothing}

Helper function to safely parse JSON
"""
function safe_json(text::String)::Union{Any,Nothing}
    try
        return JSON3.read(text)
    catch
        return nothing
    end
end

export ChatClient, ChatClientConfig, connect, disconnect, react_with_emoji

end # module 