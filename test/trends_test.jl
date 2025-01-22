using Test
using TwitterClient
using TwitterClient.TwitterTrends

@testset "Twitter Trends Tests" begin
    @testset "Get Trends" begin
        scraper = get_scraper()
        
        trends = get_trends(scraper)
        
        # Check number of trends
        @test length(trends) == 20
        
        # Check that all trends are not empty
        @test all(!isempty, trends)
        
        # Check that all trends are strings
        @test all(t -> typeof(t) == String, trends)
    end
end 