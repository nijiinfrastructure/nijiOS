module TwitterSpacesPlugins

using Base.Events
using HTTP
using JSON3
using ..TwitterSpacesLogger
using ..TwitterSpacesTypes
using ..TwitterSpacesCore

"""
    SttTtsPluginConfig

Configuration for the STT-TTS Plugin.
"""
struct SttTtsPluginConfig
    openai_api_key::Union{String,Nothing}    # for STT & ChatGPT
    elevenlabs_api_key::Union{String,Nothing} # for TTS
    stt_language::String                     # e.g., "en" for Whisper
    gpt_model::String                        # e.g., "gpt-3.5-turbo"
    silence_threshold::Int                   # Amplitude threshold for silence
    voice_id::String                         # ElevenLabs voice ID
    elevenlabs_model::String                 # e.g., "eleven_monolingual_v1"
    system_prompt::String                    # e.g., "You are a helpful AI assistant"
    debug::Bool
end

"""
    SttTtsPlugin

Provides an end-to-end flow of:
- Speech-to-Text (OpenAI Whisper)
- ChatGPT Conversation
- Text-to-Speech (ElevenLabs)
- Streams TTS Audio Frames back to Janus
"""
mutable struct SttTtsPlugin <: AbstractPlugin
    space_or_participant::Union{Space,SpaceParticipant,Nothing}
    janus::Union{JanusClient,Nothing}
    logger::Union{Logger,Nothing}
    
    # Configuration
    config::SttTtsPluginConfig
    
    # Chat context for GPT
    chat_context::Vector{Dict{String,String}}
    
    # PCM Buffer Management
    pcm_buffers::Dict{String,Vector{Vector{Int16}}}
    speaker_unmuted::Dict{String,Bool}
    
    # TTS Queue
    tts_queue::Vector{String}
    is_speaking::Bool
    
    function SttTtsPlugin(config::SttTtsPluginConfig)
        new(nothing, nothing, nothing,
            config,
            [], 
            Dict(), Dict(),
            [], false)
    end
end

"""
    on_attach(plugin::SttTtsPlugin, params::Dict)::Nothing

Called immediately after .use(plugin). Stores minimal references.
"""
function on_attach(plugin::SttTtsPlugin, params::Dict)::Nothing
    plugin.space_or_participant = params[:space]
    plugin.logger = Logger(plugin.config.debug)
    plugin.logger.info("[SttTtsPlugin] onAttach => plugin attached")
    nothing
end

"""
    init(plugin::SttTtsPlugin, params::Dict)::Nothing

Called when Space/Participant has joined in basic mode.
"""
function init(plugin::SttTtsPlugin, params::Dict)::Nothing
    plugin.logger.info("[SttTtsPlugin] init => setting up audio processing")
    
    # Add system prompt to chat context
    push!(plugin.chat_context, Dict(
        "role" => "system",
        "content" => plugin.config.system_prompt
    ))
    nothing
end

"""
    on_janus_ready(plugin::SttTtsPlugin, janus::JanusClient)::Nothing

Called when a JanusClient becomes available.
"""
function on_janus_ready(plugin::SttTtsPlugin, janus::JanusClient)::Nothing
    plugin.janus = janus
    plugin.logger.info("[SttTtsPlugin] Janus client ready")
    nothing
end

"""
    on_audio_data(plugin::SttTtsPlugin, data::AudioDataWithUser)::Nothing

Processes incoming PCM frames from speakers.
"""
function on_audio_data(plugin::SttTtsPlugin, data::AudioDataWithUser)::Nothing
    # Ignore audio if speaker is muted
    if !get(plugin.speaker_unmuted, data.user_id, false)
        return nothing
    end
    
    # Add PCM frames to buffer
    if !haskey(plugin.pcm_buffers, data.user_id)
        plugin.pcm_buffers[data.user_id] = Vector{Int16}[]
    end
    push!(plugin.pcm_buffers[data.user_id], data.samples)
    
    # Check for silence and process buffer if needed
    if should_process_buffer(plugin, data.user_id)
        @async process_audio_buffer(plugin, data.user_id)
    end
    nothing
end

# ... additional helper functions for audio processing ...

"""
    set_system_prompt(plugin::SttTtsPlugin, prompt::String)::Nothing

Updates the GPT system prompt at runtime.
"""
function set_system_prompt(plugin::SttTtsPlugin, prompt::String)::Nothing
    plugin.config.system_prompt = prompt
    plugin.logger.info("[SttTtsPlugin] setSystemPrompt =>", prompt)
    nothing
end

"""
    set_gpt_model(plugin::SttTtsPlugin, model::String)::Nothing

Changes the GPT model (e.g., "gpt-4").
"""
function set_gpt_model(plugin::SttTtsPlugin, model::String)::Nothing
    plugin.config.gpt_model = model
    plugin.logger.info("[SttTtsPlugin] setGptModel =>", model)
    nothing
end

"""
    add_message(plugin::SttTtsPlugin, role::String, content::String)::Nothing

Manually adds a system/user/assistant message to the chat context.
"""
function add_message(plugin::SttTtsPlugin, role::String, content::String)::Nothing
    push!(plugin.chat_context, Dict("role" => role, "content" => content))
    plugin.logger.debug(
        "[SttTtsPlugin] addMessage => role=$(role), content=\"$(content)\""
    )
    nothing
end

"""
    clear_chat_context(plugin::SttTtsPlugin)::Nothing

Resets the GPT conversation.
"""
function clear_chat_context(plugin::SttTtsPlugin)::Nothing
    empty!(plugin.chat_context)
    plugin.logger.debug("[SttTtsPlugin] clearChatContext => done")
    nothing
end

"""
    cleanup(plugin::SttTtsPlugin)::Nothing

Cleans up resources when the Space/Participant is stopped or the plugin is removed.
"""
function cleanup(plugin::SttTtsPlugin)::Nothing
    plugin.logger.info("[SttTtsPlugin] cleanup => releasing resources")
    
    empty!(plugin.pcm_buffers)
    empty!(plugin.speaker_unmuted)
    empty!(plugin.tts_queue)
    plugin.is_speaking = false
    nothing
end

export SttTtsPlugin, SttTtsPluginConfig

end # module 