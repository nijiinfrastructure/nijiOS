@testset "Profile Handler Tests" begin
    scraper = Scraper()
    login!(scraper, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])
    
    @testset "Profile Retrieval" begin
        username = "testuser"
        profile = get_profile(scraper, username)
        
        @test profile.username == username
        @test !isnothing(profile.id)
        @test !isnothing(profile.name)
        @test !isnothing(profile.created_at)
    end
    
    @testset "User ID Lookup" begin
        username = "testuser"
        user_id = get_user_id_by_username(scraper, username)
        
        @test !isnothing(user_id)
        @test typeof(user_id) == String
    end
end 