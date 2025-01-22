module TwitterSpacesPlugins

using Base.Events
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes
using ..TwitterSpacesCore

"""
    RecordToDiskPlugin

A simple plugin that writes all incoming PCM frames to a local .raw file.

Lifecycle:
- onAttach(...) => minimal references, logger configuration
- init(...) => finalizes file path, opens stream
- onAudioData(...) => adds PCM frames to file
- cleanup(...) => closes file stream
"""
mutable struct RecordToDiskPlugin <: AbstractPlugin
    file_path::String
    out_stream::Union{IOStream,Nothing}
    logger::Union{Logger,Nothing}

    function RecordToDiskPlugin()
        new("/tmp/speaker_audio.raw", nothing, nothing)
    end
end

"""
    on_attach(plugin::RecordToDiskPlugin, params::Dict)::Nothing

Called immediately after .use(plugin).
Creates a logger based on pluginConfig.debug and stores the file path.
"""
function on_attach(plugin::RecordToDiskPlugin, params::Dict)::Nothing
    debug_enabled = get(get(params, :plugin_config, Dict()), :debug, false)
    plugin.logger = Logger(debug_enabled)
    
    plugin.logger.info("[RecordToDiskPlugin] onAttach => plugin attached")
    
    if haskey(get(params, :plugin_config, Dict()), :file_path)
        plugin.file_path = params[:plugin_config][:file_path]
    end
    plugin.logger.debug("[RecordToDiskPlugin] Using filePath =>", plugin.file_path)
    nothing
end

"""
    init(plugin::RecordToDiskPlugin, params::Dict)::Nothing

Called after the Space/Participant has joined in basic mode.
Opens the write stream to the file path.
"""
function init(plugin::RecordToDiskPlugin, params::Dict)::Nothing
    # Check if file_path was redefined in pluginConfig
    if haskey(get(params, :plugin_config, Dict()), :file_path)
        plugin.file_path = params[:plugin_config][:file_path]
    end
    
    plugin.logger.info("[RecordToDiskPlugin] init => opening output stream")
    plugin.out_stream = open(plugin.file_path, "w")
    nothing
end

"""
    on_audio_data(plugin::RecordToDiskPlugin, data::AudioDataWithUser)::Nothing

Called when PCM audio frames arrive from a speaker.
Writes them as raw 16-bit PCM to the file.
"""
function on_audio_data(plugin::RecordToDiskPlugin, data::AudioDataWithUser)::Nothing
    if isnothing(plugin.out_stream)
        plugin.logger.warn("[RecordToDiskPlugin] No outStream yet; ignoring data")
        return nothing
    end
    
    write(plugin.out_stream, reinterpret(UInt8, data.samples))
    plugin.logger.debug(
        "[RecordToDiskPlugin] Wrote $(sizeof(data.samples)) bytes from userId=",
        "$(data.user_id) to disk"
    )
    nothing
end

"""
    cleanup(plugin::RecordToDiskPlugin)::Nothing

Called when the plugin is being cleaned up (e.g. space/participant stop).
Closes the file stream.
"""
function cleanup(plugin::RecordToDiskPlugin)::Nothing
    plugin.logger.info("[RecordToDiskPlugin] cleanup => closing output stream")
    if !isnothing(plugin.out_stream)
        close(plugin.out_stream)
        plugin.out_stream = nothing
    end
    nothing
end

export RecordToDiskPlugin

end # module 