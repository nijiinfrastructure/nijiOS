module TwitterTimelineUtils

using ..TwitterTypes
using ..TwitterTimelineTypes

const RE_HASHTAG = r"\B(\#\S+\b)"
const RE_CASHTAG = r"\B(\$\S+\b)"
const RE_TWITTER_URL = r"https:(\/\/t\.co\/([A-Za-z0-9]|[A-Za-z]){10})"
const RE_USERNAME = r"\B(\@\S{1,15}\b)"

"""
    parse_media_groups(media::Vector{TimelineMediaExtended})

Parses media groups from timeline media objects.
"""
function parse_media_groups(media::Vector{TimelineMediaExtended})
    photos = Photo[]
    videos = Video[]
    sensitive_content = nothing
    
    for m in filter(m -> !isnothing(m.id_str) && !isnothing(m.media_url_https), media)
        if m.type == "photo"
            push!(photos, Photo(
                m.id_str,
                m.media_url_https,
                m.ext_alt_text
            ))
        elseif m.type == "video"
            push!(videos, parse_video(m))
        end
        
        sensitive = m.ext_sensitive_media_warning
        if !isnothing(sensitive)
            sensitive_content = sensitive.adult_content ||
                              sensitive.graphic_violence ||
                              sensitive.other
        end
    end
    
    return (sensitive_content=sensitive_content, photos=photos, videos=videos)
end

"""
    parse_video(m::TimelineMediaExtended)

Parses a video from a timeline media object.
"""
function parse_video(m::TimelineMediaExtended)
    video = Video(
        m.id_str,
        m.media_url_https,
        nothing
    )
    
    max_bitrate = 0
    for variant in get(m.video_info, :variants, [])
        bitrate = variant.bitrate
        if !isnothing(bitrate) && bitrate > max_bitrate && !isnothing(variant.url)
            variant_url = variant.url
            tag_suffix_idx = findfirst("?tag=10", variant_url)
            if !isnothing(tag_suffix_idx)
                variant_url = variant_url[1:first(tag_suffix_idx)-1]
            end
            
            video.url = variant_url
            max_bitrate = bitrate
        end
    end
    
    return video
end

# HTML reconstruction functions
function link_hashtag_html(hashtag::AbstractString)
    return """<a href="https://twitter.com/hashtag/$(replace(hashtag, "#" => ""))">$hashtag</a>"""
end

function link_cashtag_html(cashtag::AbstractString)
    return """<a href="https://twitter.com/search?q=%24$(replace(cashtag, "\$" => ""))">$cashtag</a>"""
end

function link_username_html(username::AbstractString)
    return """<a href="https://twitter.com/$(replace(username, "@" => ""))">$username</a>"""
end

function unwrap_tco_url_html(tweet::LegacyTweetRaw, founded_media::Vector{String})
    return function(tco::AbstractString)
        # Search URLs
        for entity in get(tweet.entities, :urls, [])
            if tco == entity.url && !isnothing(entity.expanded_url)
                return """<a href="$(entity.expanded_url)">$tco</a>"""
            end
        end
        
        # Search media
        for entity in get(tweet.extended_entities, :media, [])
            if tco == entity.url && !isnothing(entity.media_url_https)
                push!(founded_media, entity.media_url_https)
                return """<br><a href="$tco"><img src="$(entity.media_url_https)"/></a>"""
            end
        end
        
        return tco
    end
end

"""
    reconstruct_tweet_html(tweet::LegacyTweetRaw, photos::Vector{Photo}, videos::Vector{Video})

Reconstructs the HTML text of a tweet.
"""
function reconstruct_tweet_html(tweet::LegacyTweetRaw, photos::Vector{Photo}, videos::Vector{Video})
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

export parse_media_groups, parse_video, reconstruct_tweet_html

end # module 