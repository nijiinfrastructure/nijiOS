module TwitterSpacesTypes

using ..TwitterSpacesCore

"""
    AudioData

Basic PCM Audio Frame properties.
"""
struct AudioData
    """Bits per sample (e.g., 16)."""
    bits_per_sample::Int

    """Sample rate in Hz (e.g., 48000 for 48kHz)."""
    sample_rate::Int

    """Number of channels (e.g., 1 for mono, 2 for stereo)."""
    channel_count::Int

    """Number of frames (samples per channel)."""
    number_of_frames::Int

    """Raw PCM data for all channels (interleaved for stereo)."""
    samples::Vector{Int16}
end

"""
    AudioDataWithUser

PCM Audio data with associated user ID indicating which speaker produced it.
"""
struct AudioDataWithUser <: AudioData
    """The ID of the speaker or user who produced this audio frame."""
    user_id::String
    
    # AudioData fields
    bits_per_sample::Int
    sample_rate::Int
    channel_count::Int
    number_of_frames::Int
    samples::Vector{Int16}
end

"""
    SpeakerRequest

Information about a speaker request event in a Space.
"""
struct SpeakerRequest
    user_id::String
    username::String
    display_name::String
    session_uuid::String
end

"""
    OccupancyUpdate

Occupancy update describing the number of participants in a Space.
"""
struct OccupancyUpdate
    occupancy::Int
    total_participants::Int
end

"""
    GuestReaction

Represents an emoji reaction event from a user in the chat.
"""
struct GuestReaction
    display_name::String
    emoji::String
end

"""
    BroadcastCreated

Response structure after creating a broadcast on Periscope/Twitter.
"""
struct BroadcastCreated
    room_id::String
    credential::String
    stream_name::String
    webrtc_gw_url::String
    broadcast::Dict{String,String}  # user_id, twitter_id, media_key
    access_token::String
    endpoint::String
    share_url::String
    stream_url::String
end

"""
    TurnServersInfo

Describes TURN server credentials and URIs.
"""
struct TurnServersInfo
    ttl::String
    username::String
    password::String
    uris::Vector{String}
end

"""
    Plugin

Defines a plugin interface for both Space (Broadcast Host) and 
SpaceParticipant (Listener/Speaker).

Lifecycle Hooks:
- on_attach(...) is called immediately after .use(plugin)
- init(...) is called after the Space/Participant has joined in basic mode
- on_janus_ready(...) is called when a JanusClient is created
- on_audio_data(...) is called when raw PCM frames are received
- cleanup(...) is called on Space/Participant stop or plugin removal
"""
abstract type Plugin end

"""
    PluginRegistration

Internal registration structure for a plugin, stores plugin instance + config.
"""
struct PluginRegistration
    plugin::Plugin
    config::Union{Dict{String,Any},Nothing}
end

"""
    SpeakerInfo

Stores information about a speaker in a Space (host perspective).
"""
struct SpeakerInfo
    user_id::String
    session_uuid::String
    janus_participant_id::Union{Int,Nothing}
end

# Export all types
export AudioData, AudioDataWithUser, SpeakerRequest, OccupancyUpdate,
       GuestReaction, BroadcastCreated, TurnServersInfo, Plugin,
       PluginRegistration, SpeakerInfo

end # module 