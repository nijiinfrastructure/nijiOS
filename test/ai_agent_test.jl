using Test
using nijiOS.AIAgent

@testset "AI Agent Tests" begin
    @testset "Tweet Generation" begin
        generator = TweetGenerator()
        
        # Test basic tweet generation
        prompt = "Write a tweet about Julia programming language"
        tweet = generate_tweet(generator, prompt)
        @test length(tweet) <= 280
        @test !isempty(tweet)
        
        # Test with context
        context = Dict(
            "tone" => "professional",
            "hashtags" => ["#JuliaLang", "#Programming"],
            "keywords" => ["performance", "scientific computing"]
        )
        
        tweet = generate_tweet(generator, prompt; context=context)
        @test length(tweet) <= 280
        @test any(hashtag -> occursin(hashtag, tweet), context["hashtags"])
    end
end 