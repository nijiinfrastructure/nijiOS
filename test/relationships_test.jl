using Test
using nijiOS
using nijiOS.TwitterRelationships

@testset "Twitter Relationships Tests" begin
    @testset "Following Tests" begin
        scraper = get_scraper()
        
        # Test Following retrieval
        following_channel = get_following("1425600122885394432", 50, scraper.auth)
        following = collect(following_channel)
        
        @test length(following) == 50
        
        # Check for duplicates
        seen_profiles = Set{String}()
        for profile in following
            @test !isnothing(profile.user_id)
            @test !in(profile.user_id, seen_profiles)
            push!(seen_profiles, profile.user_id)
            @test !isempty(profile.username)
        end
    end
    
    @testset "Followers Tests" begin
        scraper = get_scraper()
        
        # Test Followers retrieval
        followers_channel = get_followers("1425600122885394432", 50, scraper.auth)
        followers = collect(followers_channel)
        
        @test length(followers) == 50
        
        # Check for duplicates
        seen_profiles = Set{String}()
        for profile in followers
            @test !isnothing(profile.user_id)
            @test !in(profile.user_id, seen_profiles)
            push!(seen_profiles, profile.user_id)
            @test !isempty(profile.username)
        end
    end
    
    @testset "Follow User Test" begin
        scraper = get_scraper()
        
        # Test Follow User
        username = "elonmusk"
        response = follow_user(username, scraper.auth)
        @test !isnothing(response)
    end
end 