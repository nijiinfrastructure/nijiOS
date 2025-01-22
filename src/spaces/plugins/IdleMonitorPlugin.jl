module TwitterSpacesPlugins

using Base.Events
using Dates
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes
using ..TwitterSpacesCore

"""
    IdleMonitorPlugin

Überwacht Stille sowohl in Remote-Speaker-Audio als auch lokalem (gepushtem) Audio.
Falls für eine bestimmte Dauer kein Audio erkannt wird, wird ein 'idleTimeout' Event ausgelöst.
"""
mutable struct IdleMonitorPlugin <: AbstractPlugin
    space::Union{Space,Nothing}
    logger::Union{Logger,Nothing}
    
    last_speaker_audio_ms::Int64
    last_local_audio_ms::Int64
    check_interval::Union{Timer,Nothing}
    
    idle_timeout_ms::Int64
    check_every_ms::Int64
    
    function IdleMonitorPlugin(
        idle_timeout_ms::Int64=60_000,
        check_every_ms::Int64=10_000
    )
        new(nothing, nothing, 
            time_ms(), time_ms(),
            nothing,
            idle_timeout_ms,
            check_every_ms)
    end
end

"""
    time_ms()::Int64

Hilfsfunktion für aktuelle Zeit in Millisekunden.
"""
function time_ms()::Int64
    return floor(Int64, datetime2unix(now()) * 1000)
end

"""
    on_attach(plugin::IdleMonitorPlugin, params::Dict)::Nothing

Wird direkt nach .use(plugin) aufgerufen. Minimales Setup und Logger-Konfiguration.
"""
function on_attach(plugin::IdleMonitorPlugin, params::Dict)::Nothing
    plugin.space = params[:space]
    
    debug = get(get(params, :plugin_config, Dict()), :debug, false)
    plugin.logger = Logger(debug)
    
    plugin.logger.info("[IdleMonitorPlugin] onAttach => plugin attached")
    nothing
end

"""
    init(plugin::IdleMonitorPlugin, params::Dict)::Nothing

Wird aufgerufen sobald der Space initialisiert wurde. Richtet Idle-Checks ein und
überschreibt pushAudio um lokale Audio-Aktivität zu erkennen.
"""
function init(plugin::IdleMonitorPlugin, params::Dict)::Nothing
    plugin.space = params[:space]
    plugin.logger.info("[IdleMonitorPlugin] init => setting up idle checks")
    
    # Aktualisiere last_speaker_audio_ms bei eingehendem Speaker-Audio
    on(plugin.space, :audio_data_from_speaker) do _data
        plugin.last_speaker_audio_ms = time_ms()
    end
    
    # Patche space.push_audio um lokales Audio zu tracken
    original_push_audio = plugin.space.push_audio
    plugin.space.push_audio = function(samples, sample_rate)
        plugin.last_local_audio_ms = time_ms()
        original_push_audio(samples, sample_rate)
    end
    
    # Prüfe periodisch auf Stille
    plugin.check_interval = Timer(
        (timer) -> check_idle(plugin),
        0,
        interval=plugin.check_every_ms/1000
    )
    nothing
end

"""
    check_idle(plugin::IdleMonitorPlugin)::Nothing

Prüft ob idle_timeout_ms ohne Audio-Aktivität überschritten wurde.
Falls ja, löst ein 'idleTimeout' Event am Space mit { idleMs } Info aus.
"""
function check_idle(plugin::IdleMonitorPlugin)::Nothing
    now_ms = time_ms()
    last_audio = max(plugin.last_speaker_audio_ms, plugin.last_local_audio_ms)
    idle_ms = now_ms - last_audio
    
    if idle_ms >= plugin.idle_timeout_ms
        plugin.logger.warn(
            "[IdleMonitorPlugin] idleTimeout => no audio for $(idle_ms)ms"
        )
        emit(plugin.space, :idle_timeout, Dict(:idle_ms => idle_ms))
    end
    nothing
end

"""
    get_idle_time_ms(plugin::IdleMonitorPlugin)::Int64

Gibt zurück wie viele Millisekunden seit dem letzten Audio vergangen sind.
"""
function get_idle_time_ms(plugin::IdleMonitorPlugin)::Int64
    now_ms = time_ms()
    last_audio = max(plugin.last_speaker_audio_ms, plugin.last_local_audio_ms)
    return now_ms - last_audio
end

"""
    cleanup(plugin::IdleMonitorPlugin)::Nothing

Räumt Ressourcen (Timer) auf wenn das Plugin entfernt oder der Space gestoppt wird.
"""
function cleanup(plugin::IdleMonitorPlugin)::Nothing
    plugin.logger.info("[IdleMonitorPlugin] cleanup => stopping idle checks")
    if !isnothing(plugin.check_interval)
        close(plugin.check_interval)
        plugin.check_interval = nothing
    end
    nothing
end

export IdleMonitorPlugin

end # module 