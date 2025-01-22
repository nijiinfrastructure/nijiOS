module TwitterTweets

using Dates
using ..TwitterTypes

"""
    Tweet

Represents a single tweet.
"""
struct Tweet
    id::String
    conversation_id::String
    text::String
    username::String
    name::String
    url::String
    created_at::DateTime
    like_count::Int
    retweet_count::Int
    reply_count::Int
    photos::Vector{Photo}
    videos::Vector{Video}
    hashtags::Vector{String}
    mentions::Vector{UserMention}
    urls::Vector{String}
    is_quoted::Bool
    is_reply::Bool
    is_retweet::Bool
    is_pinned::Bool
    quoted_status_id::Union{String,Nothing}
    in_reply_to_status_id::Union{String,Nothing}
    retweeted_status_id::Union{String,Nothing}
    html::String
end

"""
    Photo

Represents a photo in a tweet.
"""
struct Photo
    url::String
    width::Int
    height::Int
    alt_text::Union{String,Nothing}
end

"""
    Video

Represents a video in a tweet.
"""
struct Video
    url::String
    preview_url::String
    duration::Float64
    width::Int
    height::Int
    view_count::Union{Int,Nothing}
end

"""
    UserMention

Represents a user mention in a tweet.
"""
struct UserMention
    id::String
    username::String
    name::String
end

"""
    ParseTweetResult

Result of tweet parsing.
"""
struct ParseTweetResult
    success::Bool
    tweet::Union{Tweet,String}  # Tweet on success, error message on failure
end

"""
    MediaGroups

Grouped media of a tweet.
"""
struct MediaGroups
    photos::Vector{Photo}
    videos::Vector{Video}
end

"""
    MediaGroups()

Constructor for empty MediaGroups.
"""
function MediaGroups()
    MediaGroups(Photo[], Video[])
end

"""
    parse_media_groups(media::Vector{Any})::MediaGroups

Parses media groups from raw tweet data.
"""
function parse_media_groups(media::Vector{Any})::MediaGroups
    photos = Photo[]
    videos = Video[]

    for item in media
        media_type = get(item, :type, nothing)
        
        if media_type == "photo"
            push!(photos, Photo(
                item.media_url_https,
                get(item, :original_info, Dict()).width,
                get(item, :original_info, Dict()).height,
                get(item, :ext_alt_text, nothing)
            ))
        elseif media_type in ["video", "animated_gif"]
            variants = get(get(item, :video_info, Dict()), :variants, [])
            best_variant = get_best_video_variant(variants)
            
            if !isnothing(best_variant)
                push!(videos, Video(
                    best_variant.url,
                    item.media_url_https,
                    get(get(item, :video_info, Dict()), :duration_millis, 0) / 1000.0,
                    get(item, :original_info, Dict()).width,
                    get(item, :original_info, Dict()).height,
                    get(item, :view_count, nothing)
                ))
            end
        end
    end

    return MediaGroups(photos, videos)
end

"""
    get_best_video_variant(variants::Vector{Any})::Union{Any,Nothing}

Selects the best video variant based on bitrate.
"""
function get_best_video_variant(variants::Vector{Any})::Union{Any,Nothing}
    best_variant = nothing
    max_bitrate = 0

    for variant in variants
        if get(variant, :content_type, "") == "video/mp4"
            bitrate = get(variant, :bitrate, 0)
            if bitrate > max_bitrate
                max_bitrate = bitrate
                best_variant = variant
            end
        end
    end

    return best_variant
end

export Tweet, Photo, Video, UserMention, ParseTweetResult, MediaGroups,
       parse_media_groups, get_best_video_variant

end # module 