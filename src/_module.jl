module TwitterClient

using HTTP
using JSON3
using URIs
using Base64
using Dates
using MIMEs

# Export internal modules
include("retry.jl")
include("types.jl")
include("tweet_types.jl")
include("grok_types.jl")
include("rate_limiter.jl")
include("api.jl")
include("api_v2.jl")
include("auth.jl")
include("scraper.jl")
include("tweet_handler.jl")
include("profile_handler.jl")
include("search_handler.jl")
include("media_handler.jl")
include("messages.jl")
include("relationships.jl")
include("spaces.jl")
include("timeline_handler.jl")
include("trends.jl")
include("grok_handler.jl")

# Export main types and functions
export Scraper,
       Tweet,
       TweetMetrics,
       TweetReferences,
       GrokRecommendation,
       GrokConversation,
       login!,
       logout!,
       get_tweet,
       send_tweet,
       search_tweets,
       search_users,
       get_profile,
       update_profile,
       upload_media,
       get_media,
       send_message,
       get_messages,
       follow_user,
       unfollow_user,
       get_followers,
       get_following,
       create_space,
       get_space,
       end_space,
       get_user_timeline,
       get_home_timeline,
       get_trends,
       get_trending_topics,
       get_grok_recommendations,
       get_grok_conversation

end # module 