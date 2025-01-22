module TwitterSpacesTestParticipant

using DotEnv
using Base.Events
using ..TwitterSpacesScraper
using ..TwitterSpacesCore
using ..TwitterSpacesPlugins

"""
    wait_for_approval(participant::SpaceParticipant, session_uuid::String, timeout_ms::Int=10000)

Waits until "new_speaker_accepted" matches our session_uuid,
then calls become_speaker!() or aborts after timeout.
"""
function wait_for_approval(participant::SpaceParticipant, session_uuid::String, timeout_ms::Int=10000)
    return @task begin
        resolved = Ref(false)
        approval = Channel{Nothing}(1)
        
        function handler(evt)
            if evt[:session_uuid] == session_uuid
                resolved[] = true
                off(participant, :new_speaker_accepted, handler)
                try
                    become_speaker!(participant)
                    println("[TestParticipant] Successfully became speaker!")
                    put!(approval, nothing)
                catch err
                    close(approval, err)
                end
            end
        end

        on(participant, :new_speaker_accepted, handler)

        # Timeout if no confirmation is received
        @async begin
            sleep(timeout_ms/1000)
            if !resolved[]
                off(participant, :new_speaker_accepted, handler)
                close(approval, ErrorException(
                    "[TestParticipant] Timed out waiting for speaker approval after $(timeout_ms)ms."
                ))
            end
        end

        take!(approval)
    end
end

"""
    main()

Main entry point for the "Participant" flow:
- Joins an existing Space in listener mode
- Requests speaker role
- Waits for host confirmation (with timeout)
- Optionally sends periodic beep frames when we become speaker
- Adds a clean SIGINT handler for cleanup
"""
function main()
    println("[TestParticipant] Starting...")

    # 1) Twitter Login via Scraper
    scraper = Scraper()
    login!(scraper, 
        ENV["TWITTER_USERNAME"],
        ENV["TWITTER_PASSWORD"]
    )

    # 2) Create Participant
    # Adjust AudioSpace ID
    audio_space_id = "1eaKbaNYanvxX"
    participant = SpaceParticipant(scraper, Dict(
        :space_id => audio_space_id,
        :debug => false
    ))

    # Create STT/TTS Plugin instance (Demonstration)
    stt_tts_plugin = SttTtsPlugin()
    use!(participant, stt_tts_plugin, Dict(
        :openai_api_key => ENV["OPENAI_API_KEY"],
        :elevenlabs_api_key => ENV["ELEVENLABS_API_KEY"],
        :voice_id => "D38z5RcWu1voky8WS1ja"  # Example voice
    ))

    # 3) Join Space in listener mode
    join_as_listener!(participant)
    println("[TestParticipant] HLS URL => ", get_hls_url(participant))

    # 4) Request speaker role => returns { session_uuid }
    response = request_speaker!(participant)
    session_uuid = response[:session_uuid]
    println("[TestParticipant] Requested speaker => ", session_uuid)

    # 5) Wait for host confirmation (max 15 seconds)
    try
        fetch(wait_for_approval(participant, session_uuid, 15000))
        println("[TestParticipant] Speaker approval sequence completed (ok or timed out).")
    catch err
        println(stderr, "[TestParticipant] Approval error or timeout => ", err)
        # Optional: Cancel request on timeout/error
        try
            cancel_speaker_request!(participant)
            println("[TestParticipant] Speaker request canceled after timeout or error.")
        catch cancel_err
            println(stderr, "[TestParticipant] Could not cancel the request => ", cancel_err)
        end
    end

    # (Optional) Mute/Unmute Test
    mute_self!(participant)
    println("[TestParticipant] Muted.")
    sleep(3)
    unmute_self!(participant)
    println("[TestParticipant] Unmuted.")

    # ---------------------------------------------------------
    # Example Beep Generation (sends PCM frames when we are speaker)
    # ---------------------------------------------------------
    beep_duration_ms = 500
    sample_rate = 16000
    total_samples = Int(sample_rate * beep_duration_ms / 1000) # 8000
    beep_full = Vector{Int16}(undef, total_samples)

    # Sine wave with 440Hz, Amplitude ~12000
    freq = 440
    amplitude = 12000
    for i in 1:total_samples
        t = (i-1) / sample_rate
        beep_full[i] = Int16(amplitude * sin(2 * π * freq * t))
    end

    FRAME_SIZE = 160
    function send_beep()
        println("[TestParticipant] Starting beep...")
        for offset in 1:FRAME_SIZE:length(beep_full)
            portion = beep_full[offset:min(offset+FRAME_SIZE-1, end)]
            frame = Vector{Int16}(undef, FRAME_SIZE)
            frame[1:length(portion)] .= portion
            push_audio!(participant, frame, sample_rate)
            sleep(0.01)
        end
        println("[TestParticipant] Finished beep.")
    end

    # Example: Send beep every 10s
    beep_task = @async while true
        try
            send_beep()
        catch err
            println(stderr, "[TestParticipant] beep error => ", err)
        end
        sleep(10)
    end

    # Graceful Shutdown after 60s
    shutdown_task = @async begin
        sleep(60)
        leave_space!(participant)
        println("[TestParticipant] Left space. Bye!")
        exit(0)
    end

    # Handle SIGINT for manual stop
    Base.exit_on_sigint(false)
    try
        while true
            sleep(1)
        end
    catch e
        if e isa InterruptException
            println("\n[TestParticipant] Caught interrupt signal, stopping...")
            schedule(beep_task, InterruptException(), error=true)
            schedule(shutdown_task, InterruptException(), error=true)
            leave_space!(participant)
            println("[TestParticipant] Space left. Bye!")
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
    println(stderr, "[TestParticipant] Unhandled error => ", err)
    exit(1)
end

end # module 