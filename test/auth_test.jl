using Test
using TwitterClient
using Dates
using HTTP

@testset "Twitter Auth Tests" begin
    @testset "Login Flow Tests" begin
        auth = TwitterAuth()
        
        @test !is_logged_in(auth)
        
        # Test successful login
        test_credentials = Dict(
            "username" => ENV["TWITTER_TEST_USERNAME"],
            "password" => ENV["TWITTER_TEST_PASSWORD"],
            "email" => ENV["TWITTER_TEST_EMAIL"]
        )
        
        @test_nowarn login_with_password!(auth, 
            test_credentials["username"],
            test_credentials["password"],
            test_credentials["email"]
        )
        
        @test is_logged_in(auth)
        @test !isnothing(auth.user_auth.csrf_token)
        
        # Test login error
        @test_throws ErrorException login_with_password!(
            TwitterAuth(),
            "wrong_user",
            "wrong_pass"
        )
        
        # Test token refresh
        old_token = auth.user_auth.bearer_token
        sleep(2) # Wait briefly
        refresh_token!(auth)
        @test auth.user_auth.bearer_token != old_token
        
        # Test logout
        logout!(auth)
        @test !is_logged_in(auth)
    end
end 