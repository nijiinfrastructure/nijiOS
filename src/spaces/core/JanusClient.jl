module TwitterSpacesJanusClient

using Base.Events
using HTTP
using JSON3
using WebRTC
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes
using ..TwitterSpacesJanusAudio

"""
    JanusConfig

Configuration for the JanusClient.
"""
struct JanusConfig
    webrtc_url::String      # Base URL for Janus Gateway
    room_id::String         # Room ID
    credential::String      # Token for authorization
    user_id::String        # User ID (Host/Speaker)
    stream_name::String    # Stream name
    turn_servers::TurnServersInfo
    logger::Logger
end

"""
    JanusClient

manages the Janus WebRTC session for Twitter Spaces:
- Created Janus Session and Plugin Handle
- Join the Janus Videoroom as a publisher/subscriber
- Subscribe to other speakers
- Sends local PCM frames as Opus
- Polls Janus Events
"""
mutable struct JanusClient <: AbstractEventEmitter
    config::JanusConfig
    session_id::Union{Int,Nothing}
    handle_id::Union{Int,Nothing}
    publisher_id::Union{Int,Nothing}
    
    pc::Union{RTCPeerConnection,Nothing}
    local_audio_source::Union{JanusAudioSource,Nothing}
    
    poll_active::Bool
    
    # Event Waiter für spezifische Janus Events
    event_waiters::Vector{NamedTuple{(:predicate,:resolve,:reject),
                                   Tuple{Function,Function,Function}}}
    
    # Subscriber Handles + PCs für jeden abonnierten userId
    subscribers::Dict{String,NamedTuple{(:handle_id,:pc),
                                      Tuple{Int,RTCPeerConnection}}}
    
    function JanusClient(config::JanusConfig)
        new(config, nothing, nothing, nothing, 
            nothing, nothing, false,
            [], Dict())
    end
end

"""
    initialize_guest_speaker(client::JanusClient, session_uuid::String)::Nothing

Initializes the JanusClient for a guest speaker:
1) Create session
2) Attach plugin
3) Join existing room as publisher
4) Configure local PeerConnection
5) Subscribe to existing publishers
"""
function initialize_guest_speaker(client::JanusClient, session_uuid::String)::Nothing
    client.config.logger.debug("[JanusClient] initializeGuestSpeaker() called")
    
    # 1) Create sessio
    client.session_id = create_session(client)
    client.handle_id = attach_plugin(client)
    
    # Polling start
    client.poll_active = true
    start_polling(client)
    
    # 2) Enter existing room as publisher
    evt_promise = wait_for_janus_event(client,
        e -> e.janus == "event" &&
             e.plugindata.plugin == "janus.plugin.videoroom" &&
             e.plugindata.data.videoroom == "joined",
        10000,
        "Guest Speaker joined event"
    )
    
    body = Dict(
        "request" => "join",
        "room" => client.config.room_id,
        "ptype" => "publisher",
        "display" => client.config.user_id,
        "periscope_user_id" => client.config.user_id
    )
    send_janus_message(client, client.handle_id, body)
    
    # Waiting for joined event
    evt = evt_promise()
    data = evt.plugindata.data
    client.publisher_id = data.id
    
    # 3) RTCPeerConnection for local audio
    client.pc = RTCPeerConnection(
        RTCConfiguration(
            iceServers=[RTCIceServer(
                urls=client.config.turn_servers.uris,
                username=client.config.turn_servers.username,
                credential=client.config.turn_servers.password
            )]
        )
    )
    setup_peer_events(client)
    enable_local_audio(client)
    
    # 4) Publisher configuration
    configure_publisher(client, session_uuid)
    
    # 5) Follow exisiting publsiher
    publishers = get(data, :publishers, [])
    for pub in publishers
        subscribe_speaker(client, pub.display, pub.id)
    end
    
    client.config.logger.info("[JanusClient] Guest speaker negotiation complete")
    nothing
end

"""
    subscribe_speaker(client::JanusClient, user_id::String, feed_id::Int=0)::Nothing

Subscribes to a speaker's audio feed via userId and/or feedId
"""
function subscribe_speaker(client::JanusClient, user_id::String, feed_id::Int=0)::Nothing
    # ... Implementation wie in TypeScript ...
    # Erstellt subscriber handle, RTCPeerConnection und JanusAudioSink
    nothing
end

"""
    create_session(client::JanusClient)::Int

Creates a new Janus session via POST /janus.
"""
function create_session(client::JanusClient)::Int
    transaction = random_tid()
    
    response = HTTP.post(
        client.config.webrtc_url,
        ["Authorization" => client.config.credential,
         "Content-Type" => "application/json",
         "Referer" => "https://x.com"],
        JSON3.write(Dict(
            "janus" => "create",
            "transaction" => transaction
        ))
    )
    
    if response.status != 200
        throw(ErrorException("JanusClient: Session creation failed"))
    end
    
    json = JSON3.read(String(response.body))
    if json.janus != "success"
        throw(ErrorException("JanusClient: Invalid session response"))
    end
    
    return json.data.id
end


"""
    push_local_audio(client::JanusClient, samples::Vector{Int16}, 
                    sample_rate::Int, channels::Int=1)

Pushes local PCM frames to Janus.
"""
function push_local_audio(client::JanusClient, samples::Vector{Int16}, 
                         sample_rate::Int, channels::Int=1)
    if isnothing(client.local_audio_source)
        client.config.logger.warn("JanusClient: No localAudioSource => enabling now...")
        enable_local_audio(client)
    end
    
    if !isnothing(client.local_audio_source)
        push_pcm_data(client.local_audio_source, samples, sample_rate, channels)
    end
end

export JanusClient, JanusConfig, initialize_guest_speaker, subscribe_speaker, create_session, push_local_audio

end # module 