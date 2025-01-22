using Test
using nijiOS
using nijiOS.TwitterSearch

@testset "Twitter Search Tests" begin
    @testset "Search for Tweets" begin
        scraper = get_scraper()
        
        tweets_channel = search_tweets(scraper, "twitter", 30, SearchMode.Top)
        tweets = collect(tweets_channel)
        
        @test length(tweets) == 30
        @test all(t -> !isnothing(t.id), tweets)
        @test all(t -> !isempty(t.text), tweets)
        
        # Check for duplicates
        seen_tweets = Set{String}()
        for tweet in tweets
            @test !in(tweet.id, seen_tweets)
            push!(seen_tweets, tweet.id)
        end
    end
    
    @testset "Search for Profiles" begin
        scraper = get_scraper()
        
        profiles_channel = search_profiles(scraper, "Twitter", 150)
        profiles = collect(profiles_channel)
        
        @test length(profiles) == 150
        
        # Check for duplicates
        seen_profiles = Set{String}()
        for profile in profiles
            @test !isnothing(profile.user_id)
            @test !in(profile.user_id, seen_profiles)
            push!(seen_profiles, profile.user_id)
        end
    end
end 