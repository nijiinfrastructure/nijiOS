@testset "Scraper Tests" begin
    @testset "Scraper Initialization" begin
        scraper = Scraper()
        @test !isnothing(scraper.auth)
        @test !isnothing(scraper.options)
        @test !isnothing(scraper.client)
    end
    
    @testset "Login/Logout" begin
        scraper = Scraper()
        
        # Test Login
        @test login!(scraper, "test_user", "test_pass")
        @test is_logged_in(scraper)
        
        # Test Cookie Management
        cookies = get_cookies(scraper)
        @test !isempty(cookies)
        
        # Test Logout
        @test logout!(scraper)
        @test !is_logged_in(scraper)
        @test isempty(get_cookies(scraper))
    end
    
    @testset "Cookie Management" begin
        scraper = Scraper()
        test_cookies = Dict("test_cookie" => "test_value")
        
        set_cookies!(scraper, test_cookies)
        @test get_cookies(scraper) == test_cookies
        
        clear_cookies!(scraper)
        @test isempty(get_cookies(scraper))
    end
end 