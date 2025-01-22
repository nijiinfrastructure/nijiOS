@testset "Rate Limiter Tests" begin
    scraper = Scraper()
    
    @testset "Rate Limit Checking" begin
        endpoint = "test_endpoint"
        
        # Test Rate Limit Update
        headers = Dict(
            "x-rate-limit-limit" => "100",
            "x-rate-limit-remaining" => "99",
            "x-rate-limit-reset" => string(floor(Int, time()) + 3600)
        )
        
        update_rate_limit!(scraper, endpoint, headers)
        
        @test haskey(scraper.rate_limiter.endpoints, endpoint)
        rate_limit = scraper.rate_limiter.endpoints[endpoint]
        @test rate_limit.limit == 100
        @test rate_limit.remaining == 99
    end
    
    @testset "Rate Limit Enforcement" begin
        endpoint = "test_endpoint"
        
        # Test with exhausted rate limit
        headers = Dict(
            "x-rate-limit-limit" => "100",
            "x-rate-limit-remaining" => "0",
            "x-rate-limit-reset" => string(floor(Int, time()) + 1)
        )
        
        update_rate_limit!(scraper, endpoint, headers)
        
        start_time = time()
        check_rate_limit!(scraper, endpoint)
        end_time = time()
        
        @test end_time - start_time >= 1.0
    end
end 