module TwitterSpacesPlugins

using Base.Events
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes
using ..TwitterSpacesCore

"""
    HlsRecordPlugin

Records the final Twitter Spaces HLS mix to a local .ts file.

Workflow:
- Waits for occupancy > 0 (at least one listener)
- Tried to get the HLS URL from Twitter (via scraper)
- If valid (HTTP 200), ffmpeg starts recording
- If HLS is not yet ready (HTTP 404), wait for the next occupancy event
"""
mutable struct HlsRecordPlugin <: AbstractPlugin
    logger::Union{Logger,Nothing}
    recording_process::Union{Process,Nothing}
    is_recording::Bool
    output_path::Union{String,Nothing}
    media_key::Union{String,Nothing}
    space::Union{Space,Nothing}

    function HlsRecordPlugin(output_path::Union{String,Nothing}=nothing)
        new(nothing, nothing, false, output_path, nothing, nothing)
    end
end

"""
    on_attach(plugin::HlsRecordPlugin, params::Dict)::Nothing

Called directly after .use(plugin). Stores references and creates loggers.
"""
function on_attach(plugin::HlsRecordPlugin, params::Dict)::Nothing
    plugin.space = params[:space]
    
    debug = get(get(params, :plugin_config, Dict()), :debug, false)
    plugin.logger = Logger(debug)
    
    plugin.logger.info("[HlsRecordPlugin] onAttach => plugin attached")
    
    # Falls output_path nicht im Konstruktor übergeben wurde, prüfe plugin_config
    if haskey(get(params, :plugin_config, Dict()), :output_path)
        plugin.output_path = params[:plugin_config][:output_path]
    end
    nothing
end

"""
    init(plugin::HlsRecordPlugin, params::Dict)::Nothing

Called as soon as the space has been initialized (broadcastInfo ready).
"""
function init(plugin::HlsRecordPlugin, params::Dict)::Nothing
    # Plugin config erneut prüfen
    if haskey(get(params, :plugin_config, Dict()), :output_path)
        plugin.output_path = params[:plugin_config][:output_path]
    end

    broadcast_info = plugin.space.broadcast_info
    if isnothing(broadcast_info) || isnothing(broadcast_info.broadcast.media_key)
        plugin.logger.warn("[HlsRecordPlugin] No media_key found in broadcastInfo")
        return nothing
    end
    plugin.media_key = broadcast_info.broadcast.media_key

   # If no custom output_path was specified, use default
    room_id = broadcast_info.room_id || "unknown_room"
    if isnothing(plugin.output_path)
        plugin.output_path = "/tmp/record_$(room_id).ts"
    end

    plugin.logger.info(
        "[HlsRecordPlugin] init => ready to record. Output path=\"$(plugin.output_path)\""
    )

   # Listen for occupancy updates
    on(plugin.space, :occupancy_update) do update
        try
            handle_occupancy_update(plugin, update)
        catch err
            plugin.logger.error("[HlsRecordPlugin] handleOccupancyUpdate =>", err)
        end
    end
    nothing
end

"""
    handle_occupancy_update(plugin::HlsRecordPlugin, update::OccupancyUpdate)::Nothing

If occupancy > 0 and no recording is running yet, try the HLS URL from Twitter 
pick up. If ready, start ffmpeg to record.
"""
function handle_occupancy_update(plugin::HlsRecordPlugin, update::OccupancyUpdate)::Nothing
    if isnothing(plugin.space) || isnothing(plugin.media_key) return nothing end
    if plugin.is_recording return nothing end
    if update.occupancy <= 0
        plugin.logger.debug("[HlsRecordPlugin] occupancy=0 => ignoring")
        return nothing
    end

    plugin.logger.debug(
        "[HlsRecordPlugin] occupancy=$(update.occupancy) => trying to fetch HLS URL..."
    )

    scraper = plugin.space.scraper
    if isnothing(scraper)
        plugin.logger.warn("[HlsRecordPlugin] No scraper found on space")
        return nothing
    end

    try
        status = get_audio_space_stream_status(scraper, plugin.media_key)
        if isnothing(status) || isnothing(status.source) || isnothing(status.source.location)
            plugin.logger.debug(
                "[HlsRecordPlugin] occupancy>0 but no HLS URL => wait next update"
            )
            return nothing
        end

        hls_url = status.source.location
        start_recording(plugin, hls_url)
    catch err
        plugin.logger.error("[HlsRecordPlugin] Error fetching HLS URL =>", err)
    end
    nothing
end

"""
    start_recording(plugin::HlsRecordPlugin, hls_url::String)::Nothing

Starts the ffmpeg recording of the HLS stream.
"""
function start_recording(plugin::HlsRecordPlugin, hls_url::String)::Nothing
    if plugin.is_recording return nothing end
    
    plugin.logger.info("[HlsRecordPlugin] Starting ffmpeg recording...")
    plugin.logger.debug("[HlsRecordPlugin] HLS URL =>", hls_url)
    
    try
        plugin.recording_process = open(`ffmpeg -i $hls_url -c copy $(plugin.output_path)`)
        plugin.is_recording = true
        plugin.logger.info("[HlsRecordPlugin] Recording started => $(plugin.output_path)")
    catch err
        plugin.logger.error("[HlsRecordPlugin] Failed to start ffmpeg =>", err)
    end
    nothing
end

"""
    cleanup(plugin::HlsRecordPlugin)::Nothing

Stops ffmpeg if active.
"""
function cleanup(plugin::HlsRecordPlugin)::Nothing
    if !isnothing(plugin.recording_process)
        kill(plugin.recording_process)
        plugin.recording_process = nothing
        plugin.is_recording = false
        plugin.logger.info("[HlsRecordPlugin] Stopped ffmpeg recording")
    end
    nothing
end

export HlsRecordPlugin

end # module 