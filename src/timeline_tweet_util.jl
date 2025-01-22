module TwitterTimelineTweetUtil

using ..TwitterTypes
using ..TwitterTimelineTypes

# Regular expressions for tweet text parsing
const RE_HASHTAG = r"\B(\#\S+\b)"
const RE_CASHTAG = r"\B(\$\S+\b)"
const RE_TWITTER_URL = r"https:(\/\/t\.co\/([A-Za-z0-9]|[A-Za-z]){10})"
const RE_USERNAME = r"\B(\@\S{1,15}\b)"

"""
    parse_media_groups(media::Vector{TimelineMediaExtended})

Parses media groups from a tweet.
"""
function parse_media_groups(media::Vector{TimelineMediaExtended})
    photos = Photo[]
    videos = Video[]
    sensitive_content = nothing

    # Only process media with ID and URL
    valid_media = filter(m -> !isnothing(m.id_str) && !isnothing(m.media_url_https), media)
    
    for m in valid_media
        if m.type == "photo"
            push!(photos, Photo(
                m.id_str,
                m.media_url_https,
                m.ext_alt_text
            ))
        elseif m.type == "video"
            push!(videos, parse_video(m))
        end

        # Check sensitive content
        sensitive = m.ext_sensitive_media_warning
        if !isnothing(sensitive)
            sensitive_content = sensitive.adult_content ||
                              sensitive.graphic_violence ||
                              sensitive.other
        end
    end

    return (
        sensitive_content=sensitive_content,
        photos=photos,
        videos=videos
    )
end

"""
    parse_video(m::TimelineMediaExtended)::Video

Parses a video from a media object.
"""
function parse_video(m::TimelineMediaExtended)::Video
    video = Video(
        m.id_str,
        m.media_url_https,
        nothing
    )

    # Find best video quality
    max_bitrate = 0
    variants = get(get(m, :video_info, Dict()), :variants, [])
    
    for variant in variants
        bitrate = get(variant, :bitrate, nothing)
        if !isnothing(bitrate) && bitrate > max_bitrate && !isnothing(variant.url)
            variant_url = variant.url
            # Remove tag suffix if present
            tag_suffix_idx = findfirst("?tag=10", variant_url)
            if !isnothing(tag_suffix_idx)
                variant_url = variant_url[1:tag_suffix_idx[1]-1]
            end

            video.url = variant_url
            max_bitrate = bitrate
        end
    end

    return video
end

"""
    reconstruct_tweet_html(tweet::LegacyTweetRaw, photos::Vector{Photo}, videos::Vector{Video})::String

Reconstructs the HTML text of a tweet with links and media.
"""
function reconstruct_tweet_html(tweet::LegacyTweetRaw, photos::Vector{Photo}, videos::Vector{Video})::String
    media = String[]
    html = get(tweet, :full_text, "")

    # Replace links
    html = replace(html, RE_HASHTAG => link_hashtag_html)
    html = replace(html, RE_CASHTAG => link_cashtag_html)
    html = replace(html, RE_USERNAME => link_username_html)
    html = replace(html, RE_TWITTER_URL => unwrap_tco_url_html(tweet, media))

    # Add photos
    for photo in photos
        if !(photo.url in media)
            html *= """<br><img src="$(photo.url)"/>"""
        end
    end

    # Add videos
    for video in videos
        if !(video.preview in media)
            html *= """<br><img src="$(video.preview)"/>"""
        end
    end

    # Convert line breaks
    html = replace(html, "\n" => "<br>")

    return html
end

"""
    link_hashtag_html(hashtag::AbstractString)::String

Creates an HTML link for a hashtag.
"""
function link_hashtag_html(hashtag::AbstractString)::String
    tag = replace(hashtag, "#" => "")
    return """<a href="https://twitter.com/hashtag/$tag">$hashtag</a>"""
end

"""
    link_cashtag_html(cashtag::AbstractString)::String

Creates an HTML link for a cashtag.
"""
function link_cashtag_html(cashtag::AbstractString)::String
    tag = replace(cashtag, "\$" => "")
    return """<a href="https://twitter.com/search?q=%24$tag">$cashtag</a>"""
end

"""
    link_username_html(username::AbstractString)::String

Creates an HTML link for a username.
"""
function link_username_html(username::AbstractString)::String
    name = replace(username, "@" => "")
    return """<a href="https://twitter.com/$name">$username</a>"""
end

"""
    unwrap_tco_url_html(tweet::LegacyTweetRaw, found_media::Vector{String})

Creates a function to replace t.co URLs with their original URLs.
"""
function unwrap_tco_url_html(tweet::LegacyTweetRaw, found_media::Vector{String})
    return function(tco::AbstractString)
        # Check URLs in entities
        for entity in get(get(tweet, :entities, Dict()), :urls, [])
            if tco == entity.url && !isnothing(entity.expanded_url)
                return """<a href="$(entity.expanded_url)">$tco</a>"""
            end
        end

        # Check media URLs
        for entity in get(get(tweet, :extended_entities, Dict()), :media, [])
            if tco == entity.url && !isnothing(entity.media_url_https)
                push!(found_media, entity.media_url_https)
                return """<br><a href="$tco"><img src="$(entity.media_url_https)"/></a>"""
            end
        end

        return tco
    end
end

export parse_media_groups, parse_video, reconstruct_tweet_html,
       link_hashtag_html, link_cashtag_html, link_username_html,
       unwrap_tco_url_html

end # module 