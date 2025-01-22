@testset "API Tests" begin
    scraper = Scraper()
    login!(scraper, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])
    
    @testset "URL Building" begin
        base_url = "https://api.twitter.com/2/tweets"
        query = Dict("expansions" => "author_id", "tweet.fields" => "created_at")
        
        url = TwitterClient.build_url(base_url, query)
        @test contains(url, "expansions=author_id")
        @test contains(url, "tweet.fields=created_at")
    end
    
    @testset "Header Preparation" begin
        headers = TwitterClient.prepare_headers(scraper)
        @test any(h -> h[1] == "Content-Type" && h[2] == "application/json", headers)
        @test any(h -> h[1] == "User-Agent" && contains(h[2], "TwitterClient.jl"), headers)
    end
    
    @testset "API V2 Tweet Operations" begin
        # sent tweet
        text = "Test tweet from TwitterClient.jl $(rand(1000:9999))"
        response = send_tweet_v2(scraper, text)
        @test haskey(response, "data")
        @test haskey(response["data"], "id")
        
        # get tweet
        tweet_id = response["data"]["id"]
        tweet = get_tweet_v2(scraper, tweet_id)
        @test haskey(tweet, "data")
        @test tweet["data"]["text"] == text
    end
    
    @testset "Error Handling" begin
        @test_throws TwitterAPIError get_tweet_v2(scraper, "nonexistent_id")
    end
end 