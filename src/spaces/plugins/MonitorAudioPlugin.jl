module TwitterSpacesPlugins

using Base.Events
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes

"""
    MonitorAudioPlugin

A simple plugin that starts an `ffplay` process to play PCM audio in real-time.
It reads frames from `on_audio_data()` and writes them via stdin to ffplay.
"""
mutable struct MonitorAudioPlugin <: AbstractPlugin
    ffplay::Union{Process,Nothing}
    logger::Logger
    sample_rate::Int

    function MonitorAudioPlugin(sample_rate::Int=48000, debug::Bool=false)
        logger = Logger(debug)
        
        # Start ffplay to read raw PCM (s16le) from stdin
        ffplay = try
            run(pipeline(`ffplay 
                -f s16le 
                -ar $sample_rate 
                -ac 1 
                -nodisp 
                -loglevel quiet 
                -i pipe:0`, stdin=Base.pipe()))
        catch err
            logger.error("[MonitorAudioPlugin] ffplay error =>", err)
            nothing
        end

        if !isnothing(ffplay)
            logger.info(
                "[MonitorAudioPlugin] Started ffplay for real-time monitoring",
                " (sampleRate=$sample_rate)"
            )
        end

        new(ffplay, logger, sample_rate)
    end
end

"""
    on_audio_data(plugin::MonitorAudioPlugin, data::AudioDataWithUser)::Nothing

Called when PCM frames (from a speaker) arrive.
Writes frames to ffplay's stdin to play them in real-time.
"""
function on_audio_data(plugin::MonitorAudioPlugin, data::AudioDataWithUser)::Nothing
    # Log debug info
    plugin.logger.debug(
        "[MonitorAudioPlugin] onAudioData => userId=$(data.user_id),",
        " samples=$(length(data.samples)), sampleRate=$(data.sample_rate)"
    )

    if isnothing(plugin.ffplay) || !isopen(plugin.ffplay.stdin)
        return nothing
    end

    # In this plugin, we assume that data.sample_rate matches our 
    # expected sample_rate.
    # Convert the Int16Array to a buffer and write to ffplay stdin.
    write(plugin.ffplay.stdin, reinterpret(UInt8, data.samples))
    nothing
end

"""
    cleanup(plugin::MonitorAudioPlugin)::Nothing

Cleanup is called when the plugin is removed or the Space/Participant is stopped.
Terminates the ffplay process and closes its stdin pipe.
"""
function cleanup(plugin::MonitorAudioPlugin)::Nothing
    plugin.logger.info("[MonitorAudioPlugin] Cleanup => stopping ffplay")
    if !isnothing(plugin.ffplay)
        close(plugin.ffplay.stdin)
        kill(plugin.ffplay)
        plugin.ffplay = nothing
    end
    nothing
end

export MonitorAudioPlugin

end # module 