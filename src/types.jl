# Authentication Types
"""
    abstract type AuthMethod end

Base type for different authentication methods.
"""
abstract type AuthMethod end

struct PasswordAuth <: AuthMethod
    username::String
    password::String
    email::Union{String,Nothing}
end

struct APIAuth <: AuthMethod
    api_key::String
    api_secret::String
    access_token::String
    access_token_secret::String
end

"""
    struct TwitterAuth

Main structure for Twitter authentication.

# Fields
- `password_auth::Union{PasswordAuth,Nothing}`: Password-based authentication
- `api_auth::Union{APIAuth,Nothing}`: API-based authentication
- `bearer_token::Union{String,Nothing}`: Bearer token for API access
- `cookies::Dict{String,String}`: Session cookies
"""
mutable struct TwitterAuth
    password_auth::Union{PasswordAuth,Nothing}
    api_auth::Union{APIAuth,Nothing}
    bearer_token::Union{String,Nothing}
    cookies::Dict{String,String}
end

# Constructors
TwitterAuth() = TwitterAuth(nothing, nothing, nothing, Dict{String,String}()) 

# Tweet-related Types
struct Tweet
    id::String
    text::String
    created_at::DateTime
    author_id::String
    conversation_id::String
    in_reply_to_user_id::Union{String,Nothing}
    referenced_tweets::Vector{Dict{String,Any}}
    public_metrics::Dict{String,Int}
    entities::Union{Dict{String,Any},Nothing}
end

# Profile-related Types
struct UserProfile
    id::String
    username::String
    name::String
    description::Union{String,Nothing}
    created_at::DateTime
    verified::Bool
    protected::Bool
    followers_count::Int
    following_count::Int
    tweets_count::Int
end

# Search-related Types
@enum SearchMode begin
    Latest
    Top
    People
    Photos
    Videos
end

# Rate-Limiting Types
mutable struct RateLimit
    limit::Int
    remaining::Int
    reset_at::DateTime
end

module Types

using HTTP
using Dates

export RateLimiter, Scraper, Tweet, TweetMetrics, TweetReferences

# Base Structures
"""
    RateLimiter

Manages rate limiting for Twitter API requests.
"""
mutable struct RateLimiter
    endpoints::Dict{String, Tuple{Int, DateTime}}
    RateLimiter() = new(Dict{String, Tuple{Int, DateTime}}())
end

"""
    Scraper

Manages HTTP session and rate limiting.
"""
mutable struct Scraper
    cookies::HTTP.Cookies.CookieJar
    rate_limiter::RateLimiter
    Scraper() = new(HTTP.Cookies.CookieJar(), RateLimiter())
end

# Tweet-related Types
struct TweetMetrics
    replies::Int
    retweets::Int
    likes::Int
    quotes::Int
    bookmarks::Int
    TweetMetrics() = new(0, 0, 0, 0, 0)
end

struct TweetReferences
    reply_to::Union{String, Nothing}
    quoted_tweet::Union{String, Nothing}
    retweeted_tweet::Union{String, Nothing}
    TweetReferences() = new(nothing, nothing, nothing)
end

struct Tweet
    id::String
    text::String
    author_id::String
    created_at::DateTime
    metrics::TweetMetrics
    references::TweetReferences
    attachments::Vector{String}
    lang::String
    possibly_sensitive::Bool
    source::String
end

end # module Types 