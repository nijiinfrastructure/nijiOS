module TwitterSpacesUtils

using HTTP
using JSON3
using Base.Events
using ..TwitterSpacesTypes
using ..TwitterSpacesCore
using ..TwitterSpacesLogger

"""
    authorize_token(cookie::String)::String

Authorizes a token for guest access using the provided Periscope cookie.
Returns an authorization token (bearer/JWT-like).
"""
function authorize_token(cookie::String)::String
    headers = Dict(
        "X-Periscope-User-Agent" => "Twitter/m5",
        "Content-Type" => "application/json",
        "X-Idempotence" => string(round(Int, time() * 1000)),
        "Referer" => "https://x.com/",
        "X-Attempt" => "1"
    )

    response = HTTP.post(
        "https://proxsee.pscp.tv/api/v2/authorizeToken",
        headers,
        JSON3.write(Dict(
            "service" => "guest",
            "cookie" => cookie
        ))
    )

    if response.status != 200
        throw(ErrorException(
            "authorize_token => request failed with status $(response.status)"
        ))
    end

    data = JSON3.read(String(response.body))
    if !haskey(data, :authorization_token)
        throw(ErrorException(
            "authorize_token => Missing authorization_token in response"
        ))
    end

    return data.authorization_token
end

"""
    publish_broadcast(params::Dict)::Nothing

Publishes a newly created broadcast (Space) to make it live/visible.
Usually called after broadcast creation and Janus initialization.
"""
function publish_broadcast(params::Dict)::Nothing
    headers = Dict(
        "X-Periscope-User-Agent" => "Twitter/m5",
        "Content-Type" => "application/json",
        "Referer" => "https://x.com/",
        "X-Idempotence" => string(round(Int, time() * 1000)),
        "X-Attempt" => "1"
    )

    HTTP.post(
        "https://proxsee.pscp.tv/api/v2/publishBroadcast",
        headers,
        JSON3.write(Dict(
            "accept_guests" => true,
            "broadcast_id" => params[:broadcast].room_id,
            "webrtc_handle_id" => params[:janus_handle_id],
            "webrtc_session_id" => params[:janus_session_id],
            "janus_publisher_id" => params[:janus_publisher_id],
            "janus_room_id" => params[:broadcast].room_id,
            "cookie" => params[:cookie],
            "status" => params[:title],
            "conversation_controls" => 0
        ))
    )
    nothing
end

"""
    unmute_speaker(params::Dict)::Nothing

Unmutes a speaker (POST /audiospace/unmuteSpeaker).
For host calls, session_uuid is "".
For speaker calls, pass their own session_uuid.
"""
function unmute_speaker(params::Dict)::Nothing
    url = "https://guest.pscp.tv/api/v1/audiospace/unmuteSpeaker"

    body = Dict(
        "ntpForBroadcasterFrame" => 2208988800031000000,
        "ntpForLiveFrame" => 2208988800031000000,
        "session_uuid" => get(params, :session_uuid, ""),
        "broadcast_id" => params[:broadcast_id],
        "chat_token" => params[:chat_token]
    )

    headers = Dict(
        "Content-Type" => "application/json",
        "Authorization" => params[:auth_token]
    )

    response = HTTP.post(url, headers, JSON3.write(body))
    if response.status != 200
        text = String(response.body)
        throw(ErrorException("unmute_speaker => $(response.status) $text"))
    end
    nothing
end

"""
    setup_common_chat_events(chat_client::ChatClient, logger::Logger, emitter::EventEmitter)::Nothing

Chat events helper. Adds listeners to a ChatClient and forwards them through
a given EventEmitter (e.g., Space or SpaceParticipant).
"""
function setup_common_chat_events(chat_client::ChatClient, logger::Logger, emitter::EventEmitter)::Nothing
    # Occupancy updates
    on(chat_client, :occupancy_update) do upd
        debug(logger, "[ChatEvents] occupancyUpdate => ", upd)
        emit(emitter, :occupancy_update, upd)
    end

    # Reaction events
    on(chat_client, :guest_reaction) do reaction
        debug(logger, "[ChatEvents] guestReaction => ", reaction)
        emit(emitter, :guest_reaction, reaction)
    end

    # Mute state changes
    on(chat_client, :mute_state_changed) do evt
        debug(logger, "[ChatEvents] muteStateChanged => ", evt)
        emit(emitter, :mute_state_changed, evt)
    end

    # Speaker requests
    on(chat_client, :speaker_request) do req
        debug(logger, "[ChatEvents] speakerRequest => ", req)
        emit(emitter, :speaker_request, req)
    end

    # Additional event: New speaker accepted
    on(chat_client, :new_speaker_accepted) do info
        debug(logger, "[ChatEvents] newSpeakerAccepted => ", info)
        emit(emitter, :new_speaker_accepted, info)
    end
    
    nothing
end

export authorize_token, publish_broadcast, unmute_speaker, setup_common_chat_events

end # module 