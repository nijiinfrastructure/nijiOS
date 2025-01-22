module TwitterClient

using HTTP, JSON, JSON3, URIs, Base64, Dates, MIMEs

# Load and export Types first
include("types.jl")
using .Types: Scraper, RateLimiter, Tweet, TweetMetrics, TweetReferences

# Then the other modules
include("retry.jl")
using .Retry: retry_with_backoff
include("rate_limiter.jl")
include("scraper.jl")
include("api.jl")
include("api_v2.jl")
include("auth.jl")
include("tweet_handler.jl")
include("profile_handler.jl")
include("search_handler.jl")
include("media_handler.jl")
include("messages.jl")
include("relationships.jl")
include("spaces.jl")
include("timeline_handler.jl")
include("trends.jl")
include("ai_agent.jl")

# Export all public functions and types
export 
    # Types
    Scraper, RateLimiter, Tweet, TweetMetrics, TweetReferences,
    # Functions
    create_scraper, init_scraper!, login!, logout!,
    get_tweet, send_tweet, search_tweets, search_users,
    TweetGenerator, generate_tweet

"""
    post_ai_tweet(scraper::Scraper, prompt::String; context::Dict=Dict())

Generates and posts a tweet using AI, based on the given prompt and context.
"""
function post_ai_tweet(scraper::Scraper, prompt::String; context::Dict=Dict())
    generator = TweetGenerator()
    tweet_text = generate_tweet(generator, prompt; context=context)
    return post_tweet(scraper, tweet_text)
end

export post_ai_tweet

end # module 