@testset "Search Handler Tests" begin
    scraper = Scraper()
    login!(scraper, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])
    
    @testset "Tweet Search" begin
        query = "test"
        tweets = search_tweets(scraper, query, Latest, 5)
        
        @test length(tweets) <= 5
        @test all(t -> !isnothing(t.id), tweets)
        @test all(t -> !isnothing(t.text), tweets)
    end
    
    @testset "Search Modes" begin
        query = "test"
        
        latest_tweets = search_tweets(scraper, query, Latest, 3)
        @test !isempty(latest_tweets)
        
        top_tweets = search_tweets(scraper, query, Top, 3)
        @test !isempty(top_tweets)
    end
end 