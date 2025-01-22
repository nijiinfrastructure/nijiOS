module TwitterCommandTest

using Test
using ..TwitterCommand
using ..TwitterTestUtils
using JSON3

@testset "Twitter CLI Tests" begin
    # Setup
    test_scraper = get_test_scraper()
    test_tweet_text = "Test tweet $(now())"
    test_tweet_id = nothing
    
    @testset "Login and Cookie Management" begin
        # Delete cookies if they exist
        cookie_path = joinpath(@__DIR__, "cookies.json")
        isfile(cookie_path) && rm(cookie_path)
        
        @test !isfile(cookie_path)
        
        # Test login
        @test_logs (:info, "Logged in and cookies saved.") begin
            login_and_save_cookies()
        end
        
        @test isfile(cookie_path)
        
        # Test cookie format
        cookies = JSON3.read(read(cookie_path, String))
        @test cookies isa Vector
        if !isempty(cookies)
            cookie = first(cookies)
            @test haskey(cookie, :key)
            @test haskey(cookie, :value)
            @test haskey(cookie, :domain)
            @test haskey(cookie, :path)
        end
    end

    @testset "Tweet Commands" begin
        # Send tweet
        response = @test_logs begin
            send_tweet_command(test_tweet_text)
        end
        @test !isnothing(response)
        test_tweet_id = response

        # Tweet with media
        test_image_path = joinpath(@__DIR__, "test_data", "test_image.jpg")
        if isfile(test_image_path)
            response = @test_logs begin
                send_tweet_command(test_tweet_text, [test_image_path])
            end
            @test !isnothing(response)
        end

        # Reply to tweet
        if !isnothing(test_tweet_id)
            reply_text = "Test reply $(now())"
            response = @test_logs begin
                reply_to_tweet(test_tweet_id, reply_text)
            end
            @test !isnothing(response)
        end
    end

    @testset "Tweet Interactions" begin
        if !isnothing(test_tweet_id)
            # Like
            @test_logs begin
                execute_command("like $(test_tweet_id)")
            end

            # Retweet
            @test_logs begin
                execute_command("retweet $(test_tweet_id)")
            end

            # Get replies
            replies = @test_logs begin
                get_replies_to_tweet(test_tweet_id)
            end
            @test replies isa Vector
        end
    end

    @testset "User Interactions" begin
        test_username = ENV["TWITTER_USERNAME"]
        
        # Get tweets
        @test_logs begin
            execute_command("get-tweets $(test_username)")
        end

        # Get mentions
        @test_logs begin
            execute_command("get-mentions")
        end

        # Follow user
        @test_logs begin
            execute_command("follow $(test_username)")
        end
    end

    @testset "CLI Command Processing" begin
        # Show help
        @test_logs begin
            execute_command("help")
        end

        # Invalid command
        @test_logs (:info, r"Unknown command:.*") begin
            execute_command("invalid-command")
        end

        # Missing parameters
        @test_logs (:info, r"Please specify.*") begin
            execute_command("send-tweet")
        end

        # Invalid tweet ID
        @test_logs (:error, r"Error.*") begin
            execute_command("like invalid-id")
        end
    end

    @testset "Media Processing" begin
        # Media type detection
        @test get_media_type(".jpg") == "image/jpeg"
        @test get_media_type(".png") == "image/png"
        @test get_media_type(".gif") == "image/gif"
        @test get_media_type(".mp4") == "video/mp4"
        @test get_media_type(".unknown") == "application/octet-stream"

        # Get photos from tweet
        if !isnothing(test_tweet_id)
            @test_logs begin
                get_photos_from_tweet(test_tweet_id)
            end
        end
    end

    @testset "Error Handling" begin
        # Invalid credentials
        @test_throws ErrorException begin
            withenv("TWITTER_USERNAME" => "invalid",
                   "TWITTER_PASSWORD" => "invalid") do
                login_and_save_cookies()
            end
        end

        # Invalid tweet ID
        @test_throws ErrorException begin
            get_photos_from_tweet("invalid-id")
        end

        # Invalid username
        @test_throws ErrorException begin
            execute_command("follow invalid-username-123456789")
        end
    end
end

end # module 