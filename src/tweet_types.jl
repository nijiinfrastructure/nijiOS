module TweetTypes

using Dates  # Added for DateTime

export Tweet, TweetMetrics, TweetReferences

"""
    TweetMetrics

Contains the metrics of a tweet (likes, retweets, etc.)
"""
struct TweetMetrics
    replies::Int
    retweets::Int
    likes::Int
    quotes::Int
    bookmarks::Int
end

"""
    TweetReferences

Contains references to other tweets (replies, quotes, etc.)
"""
struct TweetReferences
    reply_to::Union{String, Nothing}
    quoted_tweet::Union{String, Nothing}
    retweeted_tweet::Union{String, Nothing}
end

"""
    Tweet

Represents a tweet with all relevant information.
"""
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

# Constructors with default values
TweetMetrics() = TweetMetrics(0, 0, 0, 0, 0)
TweetReferences() = TweetReferences(nothing, nothing, nothing)

end # module 