@testset "Tweet Handler Tests" begin
    scraper = Scraper()
    login!(scraper, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])
    
    @testset "Single Tweet Retrieval" begin
        tweet_id = "1234567890"
        tweet = get_tweet(scraper, tweet_id)
        
        @test tweet.id == tweet_id
        @test !isnothing(tweet.text)
        @test !isnothing(tweet.created_at)
        @test !isnothing(tweet.author_id)
    end
    
    @testset "Multiple Tweets Retrieval" begin
        username = "testuser"
        tweets = get_tweets(scraper, username, 10)
        
        @test length(tweets) <= 10
        @test all(t -> !isnothing(t.id), tweets)
        @test all(t -> !isnothing(t.text), tweets)
    end
end

@testset "Extended Tweet Functionality Tests" begin
    scraper = Scraper()
    login!(scraper, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])
    
    @testset "Media Upload" begin
        # Image upload test
        test_image = "test/fixtures/test_image.jpg"
        media = upload_media(scraper, test_image, alt_text="Test Image")
        @test !isnothing(media.media_id)
        @test media.media_type == "image/jpeg"
        @test media.alt_text == "Test Image"
        
        # Tweet with media
        text = "Test tweet with media"
        options = TweetOptions(media_ids=[media.media_id])
        response = send_tweet(scraper, text, options)
        @test haskey(response, "data")
        @test haskey(response["data"], "id")
    end
    
    @testset "Poll Creation" begin
        poll = Poll([
            PollOption("Option 1", 1),
            PollOption("Option 2", 2)
        ], 1440)  # 24 hours
        
        options = TweetOptions(poll=poll)
        response = send_tweet(scraper, "Test poll tweet", options)
        @test haskey(response, "data")
        @test haskey(response["data"], "id")
    end
    
    @testset "Thread Creation" begin
        tweets = [
            "This is tweet 1 of the thread",
            "This is tweet 2 of the thread",
            "This is the final tweet"
        ]
        
        thread = create_thread(scraper, tweets)
        @test length(thread) == length(tweets)
        @test all(t -> haskey(t, "id"), thread)
    end
end 