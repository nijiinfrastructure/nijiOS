module TwitterSpacesTest

using DotEnv
using Base.Events
using ..TwitterSpacesScraper
using ..TwitterSpacesCore
using ..TwitterSpacesPlugins
using ..TwitterSpacesTypes

"""
    main()

Main entry point for the test.
"""
function main()
    println("[Test] Starting...")
    
    # 1) Twitter Login with Scraper
    scraper = Scraper()
    login!(scraper, 
        ENV["TWITTER_USERNAME"],
        ENV["TWITTER_PASSWORD"]
    )

    # 2) Create Space instance
    # debug=true for more logs
    space = Space(scraper, Dict(:debug => false))

    # --------------------------------------------------------------------------------
    # EXAMPLE 1: Record raw speaker audio with RecordToDiskPlugin
    # --------------------------------------------------------------------------------
    record_plugin = RecordToDiskPlugin()
    use!(space, record_plugin)

    # --------------------------------------------------------------------------------
    # EXAMPLE 2: HLSRecordPlugin => Record final space mix as .ts file via HLS
    # (Requires "scraper" for HLS URL and installed ffmpeg)
    # --------------------------------------------------------------------------------
    hls_plugin = HlsRecordPlugin()
    # Optional: Override default output path:
    # use!(space, hls_plugin, Dict(:output_path => "/tmp/my_custom_space.ts"))
    use!(space, hls_plugin)

    # Create STT/TTS Plugin instance
    stt_tts_plugin = SttTtsPlugin()
    use!(space, stt_tts_plugin, Dict(
        :openai_api_key => ENV["OPENAI_API_KEY"],
        :elevenlabs_api_key => ENV["ELEVENLABS_API_KEY"],
        :voice_id => "D38z5RcWu1voky8WS1ja"  # Example
    ))

    # Create IdleMonitorPlugin - stops after 60s of silence
    idle_plugin = IdleMonitorPlugin(60_000, 10_000)
    use!(space, idle_plugin)

    # On Idle: Say goodbye and end space
    on(space, :idle_timeout) do info
        println("[Test] idleTimeout => no audio for $(info[:idle_ms])ms.")
        speak_text!(stt_tts_plugin, "Ending Space due to inactivity. Goodbye!")
        sleep(10)
        stop!(space)
        println("[Test] Space stopped due to silence.")
        exit(0)
    end

    # 3) Initialize Space
    config = SpaceConfig(
        mode="INTERACTIVE",
        title="AI Chat - Dynamic GPT Config",
        description="Space that demonstrates dynamic GPT personalities.",
        languages=["en"]
    )

    broadcast_info = initialize!(space, config)
    space_url = replace(broadcast_info.share_url, "broadcasts" => "spaces")
    println("[Test] Space created => ", space_url)

    # (Optional) Tweet Space link
    send_tweet!(scraper, "$(config.title) $(space_url)")
    println("[Test] Tweet sent")

    # ---------------------------------------
    # Example of dynamic GPT usage:
    # Change system prompt at runtime
    @async begin
        sleep(45)
        println("[Test] Changing system prompt to a new persona...")
        set_system_prompt!(stt_tts_plugin,
            "You are a very sarcastic AI who uses short answers.")
    end

    # Switch to GPT-4 after some time
    @async begin
        sleep(60)
        println("[Test] Switching GPT model to \"gpt-4\" (if available)...")
        set_gpt_model!(stt_tts_plugin, "gpt-4")
    end

    # Manually call askChatGPT and speak the result
    @async begin
        sleep(75)
        println("[Test] Asking GPT for an introduction...")
        try
            response = ask_chat_gpt!(stt_tts_plugin, "Introduce yourself")
            println("[Test] ChatGPT introduction => ", response)
            speak_text!(stt_tts_plugin, response)
        catch err
            println(stderr, "[Test] askChatGPT error => ", err)
        end
    end

    # Example: Periodic greeting every 20s
    @async while true
        try
            speak_text!(stt_tts_plugin, 
                "Hello everyone, this is an automated greeting.")
        catch err
            println(stderr, "[Test] speakText() => ", err)
        end
        sleep(20)
    end

    # 4) Event Listeners
    on(space, :speaker_request) do req
        println("[Test] Speaker request => ", req)
        approve_speaker!(space, req[:user_id], req[:session_uuid])

        # Remove speaker after 60 seconds (test only)
        @async begin
            sleep(60)
            println("[Test] Removing speaker => userId=$(req[:user_id]) (after 60s)")
            try
                remove_speaker!(space, req[:user_id])
            catch err
                println(stderr, "[Test] removeSpeaker error => ", err)
            end
        end
    end

    # Respond with emoji on user reaction
    on(space, :guest_reaction) do evt
        emojis = ["💯", "✨", "🙏", "🎮"]
        emoji = emojis[rand(1:length(emojis))]
        react_with_emoji!(space, emoji)
    end

    on(space, :error) do err
        println(stderr, "[Test] Space Error => ", err)
    end

    # ==================================================
    # BEEP GENERATION (500 ms) @16kHz => 8000 samples
    # ==================================================
    beep_duration_ms = 500
    sample_rate = 16000
    total_samples = Int(sample_rate * beep_duration_ms / 1000) # 8000
    beep_full = Vector{Int16}(undef, total_samples)

    # Sine wave: 440Hz, Amplitude ~12000
    freq = 440
    amplitude = 12000
    for i in 1:total_samples
        t = (i-1) / sample_rate
        beep_full[i] = Int16(amplitude * sin(2 * π * freq * t))
    end

    FRAME_SIZE = 160

    """
        send_beep()
    
    Sends a beep by splitting beep_full into 160-sample frames.
    """
    function send_beep()
        println("[Test] Starting beep...")
        for offset in 1:FRAME_SIZE:length(beep_full)
            portion = beep_full[offset:min(offset+FRAME_SIZE-1, end)]
            frame = Vector{Int16}(undef, FRAME_SIZE)
            frame[1:length(portion)] .= portion
            push_audio!(space, frame, sample_rate)
            sleep(0.01)
        end
        println("[Test] Finished beep")
    end

    println("[Test] Space is running... press Ctrl+C to exit.")

    # Graceful Shutdown
    Base.exit_on_sigint(false)
    try
        while true
            sleep(1)
        end
    catch e
        if e isa InterruptException
            println("\n[Test] Caught interrupt signal, stopping...")
            stop!(space)
            println("[Test] Space stopped. Bye!")
            exit(0)
        else
            rethrow()
        end
    end
end

# Main program with error handling
try
    main()
catch err
    println(stderr, "[Test] Unhandled main error => ", err)
    exit(1)
end

end # module 