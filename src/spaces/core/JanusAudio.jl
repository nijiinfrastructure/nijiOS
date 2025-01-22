module TwitterSpacesJanusAudio

using Base.Events
using ..TwitterSpacesLogger

"""
    AudioSourceOptions

Configuration options for JanusAudioSource
"""
struct AudioSourceOptions
    logger::Union{Logger,Nothing}
end

"""
    AudioSinkOptions

Configuration options for JanusAudioSink.
"""
struct AudioSinkOptions
    logger::Union{Logger,Nothing}
end

"""
    JanusAudioSource

Wrapper for RTCAudioSource, allows pushing raw PCM frames
(Int16Array) into the WebRTC pipeline.
"""
mutable struct JanusAudioSource <: AbstractEventEmitter
    source::Any  # RTCAudioSource
    track::MediaStreamTrack
    logger::Union{Logger,Nothing}
    
    function JanusAudioSource(options::Union{AudioSourceOptions,Nothing}=nothing)
        source = RTCAudioSource()
        track = create_track(source)
        new(source, track, options?.logger)
    end
end

"""
    get_track(source::JanusAudioSource)::MediaStreamTrack

Returns the MediaStreamTrack for this audio source.
"""
function get_track(source::JanusAudioSource)::MediaStreamTrack
    return source.track
end

"""
    push_pcm_data(source::JanusAudioSource, samples::Vector{Int16}, 
                  sample_rate::Int, channels::Int=1)

Pushes PCM data into the RTCAudioSource. Typically 16-bit, single or multi-channel frames.
"""
function push_pcm_data(source::JanusAudioSource, samples::Vector{Int16}, 
                      sample_rate::Int, channels::Int=1)
    if !isnothing(source.logger) && source.logger.is_debug_enabled()
        source.logger.debug(
            "[JanusAudioSource] pushPcmData => " *
            "sampleRate=$sample_rate, " *
            "channels=$channels, " *
            "frames=$(length(samples))"
        )
    end
    
    # Daten in RTCAudioSource einspeisen
    on_data(source.source, Dict(
        "samples" => samples,
        "sampleRate" => sample_rate,
        "bitsPerSample" => 16,
        "channelCount" => channels,
        "numberOfFrames" => div(length(samples), channels)
    ))
end

"""
    JanusAudioSink

Wrapper for RTCAudioSink, provides an event emitter,
which forwards raw PCM frames (Int16Array) to listeners.
"""
mutable struct JanusAudioSink <: AbstractEventEmitter
    sink::Any  # RTCAudioSink
    active::Bool
    logger::Union{Logger,Nothing}
    
    function JanusAudioSink(track::MediaStreamTrack, 
                           options::Union{AudioSinkOptions,Nothing}=nothing)
        if track.kind != "audio"
            throw(ErrorException("[JanusAudioSink] Provided track is not an audio track"))
        end
        
        sink = RTCAudioSink(track)
        new(sink, true, options?.logger)
    end
end

"""
    setup_sink_handler(sink::JanusAudioSink)

Sets up the handler for incoming PCM frames.
"""
function setup_sink_handler(sink::JanusAudioSink)
    on_data(sink.sink) do frame
        if !sink.active 
            return
        end
        
        if !isnothing(sink.logger) && sink.logger.is_debug_enabled()
            sink.logger.debug(
                "[JanusAudioSink] ondata => " *
                "sampleRate=$(frame.sampleRate), " *
                "bitsPerSample=$(frame.bitsPerSample), " *
                "channelCount=$(frame.channelCount), " *
                "frames=$(length(frame.samples))"
            )
        end
        
        # 'audioData' Event mit rohem PCM Frame emittieren
        emit(sink, :audioData, frame)
    end
end

"""
    stop(sink::JanusAudioSink)

Stops receiving audio data. After the call, no more will be added
'audioData' events are emitted more.
"""
function stop(sink::JanusAudioSink)
    sink.active = false
    if !isnothing(sink.logger) && sink.logger.is_debug_enabled()
        sink.logger.debug("[JanusAudioSink] stop called => stopping the sink")
    end
    if !isnothing(sink.sink)
        stop(sink.sink)
    end
end

export JanusAudioSource, JanusAudioSink, 
       AudioSourceOptions, AudioSinkOptions,
       get_track, push_pcm_data, stop

end # module 