module TwitterSpaces

using HTTP
using JSON3
using Dates
using ..TwitterAPI
using ..TwitterAuth
using URIs
using ..API
using ..APIv2
using ..Retry
using ..Types

"""
Represents a Twitter Space
"""
struct AudioSpace
    id::String
    state::String
    title::String
    created_at::DateTime
    scheduled_start::Union{DateTime,Nothing}
    started_at::Union{DateTime,Nothing}
    ended_at::Union{DateTime,Nothing}
    host_ids::Vector{String}
    participant_ids::Vector{String}
    speaker_ids::Vector{String}
    subscriber_count::Int
    is_ticketed::Bool
end

"""
Represents a Space Community
"""
struct Community
    id::String
    name::String
    description::String
    members_count::Int
    is_pinned::Bool
end

"""
Represents a Space Subtopic
"""
struct Subtopic
    id::String
    name::String
    topic_id::String
end

"""
Parameters for Space queries
"""
struct AudioSpaceByIdVariables
    id::String
    is_ticket_holder::Bool
    is_admin::Bool
    is_member::Bool
end

"""
    fetch_audio_space_by_id(variables::AudioSpaceByIdVariables, 
                           auth::TwitterAuth)::AudioSpace

Fetches details of an Audio Space by its ID.
"""
function fetch_audio_space_by_id(variables::AudioSpaceByIdVariables, 
                               auth::TwitterAuth)::AudioSpace
    
    query_id = "Tvv_cNXCbtTcgdy1vWYPMw"  # Specific for AudioSpaceById GraphQL query
    operation_name = "AudioSpaceById"
    
    # Features for the request
    features = Dict{String,Bool}(
        "spaces_2022_h2_spaces_communities" => true,
        "spaces_2022_h2_clipping" => true,
        "creator_subscriptions_tweet_preview_api_enabled" => true,
        "profile_label_improvements_pcf_label_in_post_enabled" => false,
        "rweb_tipjar_consumption_enabled" => true,
        "responsive_web_graphql_exclude_directive_enabled" => true,
        "verified_phone_label_enabled" => false,
        "premium_content_api_read_enabled" => false,
        "communities_web_enable_tweet_community_results_fetch" => true,
        "c9s_tweet_anatomy_moderator_badge_enabled" => true,
        "responsive_web_grok_analyze_button_fetch_trends_enabled" => true,
        "articles_preview_enabled" => true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled" => false,
        "responsive_web_edit_tweet_api_enabled" => true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled" => true,
        "view_counts_everywhere_api_enabled" => true,
        "longform_notetweets_consumption_enabled" => true,
        "responsive_web_twitter_article_tweet_consumption_enabled" => true,
        "tweet_awards_web_tipping_enabled" => false,
        "creator_subscriptions_quote_tweet_preview_enabled" => false,
        "freedom_of_speech_not_reach_fetch_enabled" => true,
        "standardized_nudges_misinfo" => true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled" => true,
        "rweb_video_timestamps_enabled" => true,
        "longform_notetweets_rich_text_read_enabled" => true,
        "longform_notetweets_inline_media_enabled" => true,
        "responsive_web_graphql_timeline_navigation_enabled" => true,
        "responsive_web_enhance_cards_enabled" => false
    )

    # Prepare URL parameters
    variables_encoded = HTTP.escapeuri(JSON3.write(variables))
    features_encoded = HTTP.escapeuri(JSON3.write(features))
    
    url = "https://x.com/i/api/graphql/$(query_id)/$(operation_name)?variables=$(variables_encoded)&features=$(features_encoded)"
    
    # Prepare headers
    headers = prepare_headers(auth)
    
    # Execute request
    response = make_request(auth, "GET", url, headers)
    
    # Process response
    if !response.success
        throw(TwitterAPIError("Failed to fetch Audio Space: $(response.error)"))
    end
    
    return parse_audio_space_response(response.data)
end

"""
    parse_audio_space_response(data::Dict)::AudioSpace

Parses the API response into an AudioSpace object.
"""
function parse_audio_space_response(data::Dict)::AudioSpace
    space_data = data["data"]["audioSpace"]
    
    AudioSpace(
        space_data["id"],
        space_data["state"],
        space_data["title"],
        DateTime(space_data["created_at"]),
        get(space_data, "scheduled_start", nothing),
        get(space_data, "started_at", nothing),
        get(space_data, "ended_at", nothing),
        String[id for id in space_data["host_ids"]],
        String[id for id in space_data["participant_ids"]],
        String[id for id in space_data["speaker_ids"]],
        space_data["subscriber_count"],
        space_data["is_ticketed"]
    )
end

"""
    browse_space_topics()::Vector{Subtopic}

Retrieves available Space topics.
"""
function browse_space_topics()::Vector{Subtopic}
    # Implementation for Space topics retrieval
    # TODO: Implement API call and parsing
    return Subtopic[]
end

"""
    generate_random_id()::String

Generates a random ID in UUID v4 format.
"""
function generate_random_id()::String
    return replace("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", r"[xy]" => function(c)
        r = rand(0:15)
        v = c == 'x' ? r : (r & 0x3) | 0x8
        return string(v, base=16)
    end)
end

export AudioSpace, Community, Subtopic, AudioSpaceByIdVariables,
       fetch_audio_space_by_id, browse_space_topics, generate_random_id

end # module

export create_space, get_space, end_space

"""
    create_space(scraper, title; scheduled_start=nothing)

Creates a new Space.
"""
function create_space(scraper::Scraper, title; scheduled_start=nothing)
    body = Dict("title" => title)
    if scheduled_start !== nothing
        body["scheduled_start"] = scheduled_start
    end
    
    response = make_request(
        scraper,
        "POST",
        "https://api.twitter.com/2/spaces",
        ["Content-Type" => "application/json"],
        JSON3.write(body)
    )
    
    return JSON3.read(response.body)
end

"""
    get_space(scraper, space_id)

Retrieves information about a Space.
"""
function get_space(scraper::Scraper, space_id)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/spaces/$space_id",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

"""
    end_space(scraper, space_id)

Ends a running Space.
"""
function end_space(scraper::Scraper, space_id)
    response = make_request(
        scraper,
        "DELETE",
        "https://api.twitter.com/2/spaces/$space_id",
        ["Content-Type" => "application/json"]
    )
    
    return response.status == 200
end

end # module 