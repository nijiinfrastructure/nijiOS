using Test
using nijiOS
using Dates
using JSON3
using HTTP
using URIs

# Environment Setup
@testset "Environment Setup" begin
    @test haskey(ENV, "TWITTER_USERNAME") "TWITTER_USERNAME not set"
    @test haskey(ENV, "TWITTER_PASSWORD") "TWITTER_PASSWORD not set"
end

# Bestehende Tests einbinden
include("auth_test.jl")
include("scraper_test.jl")
include("api_test.jl")
include("tweet_handler_test.jl")
include("grok_test.jl")

# Cleanup nach Tests
@testset "Cleanup" begin
    # Temporäre Test-Dateien löschen
    if isfile("test/fixtures/test_image.jpg")
        rm("test/fixtures/test_image.jpg")
    end
end

@testset "nijiOS.jl" begin
    @testset "Types" begin
        # Test RateLimiter Konstruktor
        rate_limiter = RateLimiter()
        @test rate_limiter.endpoints isa Dict

        # Test Scraper Konstruktor
        scraper = create_scraper()
        @test scraper isa Scraper
        @test scraper.cookies isa HTTP.Cookies.CookieJar
        @test scraper.rate_limiter isa RateLimiter

        # Test Tweet-bezogene Typen
        metrics = TweetMetrics()
        @test metrics.replies == 0
        @test metrics.retweets == 0
        @test metrics.likes == 0
        @test metrics.quotes == 0
        @test metrics.bookmarks == 0

        refs = TweetReferences()
        @test refs.reply_to === nothing
        @test refs.quoted_tweet === nothing
        @test refs.retweeted_tweet === nothing
    end

    @testset "Rate Limiting" begin
        scraper = create_scraper()
        endpoint = "test_endpoint"
        
        # Simuliere HTTP Response
        headers = [
            "x-rate-limit-remaining" => "150",
            "x-rate-limit-reset" => string(Int(floor(datetime2unix(now() + Hour(1)))))
        ]
        response = HTTP.Response(200, headers)
        
        # Test Rate Limit Update
        nijiOS.TwitterRateLimiter.update_rate_limit(scraper.rate_limiter, endpoint, response)
        @test haskey(scraper.rate_limiter.endpoints, endpoint)
        
        # Test Rate Limit Check
        nijiOS.TwitterRateLimiter.check_rate_limit(scraper.rate_limiter, endpoint)
        @test true  # Sollte keine Exception werfen
    end

    @testset "API Requests" begin
        scraper = create_scraper()
        
        # Test Login/Logout (ohne tatsächliche API-Calls)
        @test_throws Exception login!(scraper, "test", "test")  # Sollte fehlschlagen ohne echte Credentials
        @test logout!(scraper) == true
        @test isempty(scraper.cookies.cookies)
    end

    @testset "Scraper Creation" begin
        scraper = create_scraper()
        @test scraper isa Scraper
        @test scraper.rate_limiter isa RateLimiter
    end
    
    # Test Login
    @testset "Authentication" begin
        scraper = create_scraper()
        # ... weitere Tests ...
    end

    @testset "Tweet Operations" begin
        # Test Tweet Abruf
        @test typeof(get_tweet(scraper, "12345")) == Tweet
        # ... weitere Tests
    end
end 