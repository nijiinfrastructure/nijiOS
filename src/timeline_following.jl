module TwitterTimelineFollowing

using HTTP
using JSON3
using ..TwitterTypes
using ..TwitterAPI
using ..TwitterAuth
using ..TwitterTimelineV2

"""
    fetch_following_timeline(count::Int, seen_tweet_ids::Vector{String}, 
                           scraper::Scraper)::Vector{Any}

Fetches the following timeline of a user.
"""
function fetch_following_timeline(count::Int, seen_tweet_ids::Vector{String}, 
                                scraper::Scraper)::Vector{Any}
    # Variables for GraphQL query
    variables = Dict(
        "count" => count,
        "includePromotedContent" => true,
        "latestControlAvailable" => true,
        "requestContext" => "launch",
        "seenTweetIds" => seen_tweet_ids
    )

    # Features for GraphQL query
    features = Dict(
        "profile_label_improvements_pcf_label_in_post_enabled" => true,
        "rweb_tipjar_consumption_enabled" => true,
        "responsive_web_graphql_exclude_directive_enabled" => true,
        "verified_phone_label_enabled" => false,
        "creator_subscriptions_tweet_preview_api_enabled" => true,
        "responsive_web_graphql_timeline_navigation_enabled" => true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled" => false,
        "communities_web_enable_tweet_community_results_fetch" => true,
        "c9s_tweet_anatomy_moderator_badge_enabled" => true,
        "articles_preview_enabled" => true,
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
        "responsive_web_enhance_cards_enabled" => false
    )

    # Create GraphQL query URL
    url = "https://x.com/i/api/graphql/K0X1xbCZUjttdK8RazKAlw/HomeLatestTimeline"
    query_params = Dict(
        "variables" => JSON3.write(variables),
        "features" => JSON3.write(features)
    )

    # Execute request
    response = make_request(
        scraper,
        "GET",
        url;
        query=query_params
    )

    if !response.success
        if response.error isa ApiError
            @error "API Error Details:" response.error.data
        end
        throw(response.error)
    end

    # Extract timeline data
    home = get(get(get(response.data, :data, Dict()), :home, Dict()),
               :home_timeline_urt, Dict())
    instructions = get(home, :instructions, [])

    if isempty(instructions)
        return []
    end

    # Collect entries
    entries = Any[]
    for instruction in instructions
        if instruction.type == "TimelineAddEntries"
            for entry in get(instruction, :entries, [])
                push!(entries, entry)
            end
        end
    end

    # Extract tweets from entries
    tweets = filter(entry -> !isnothing(get(get(get(entry, :content, Dict()),
                                              :itemContent, Dict()),
                                          :tweet_results, Dict()).result),
                   entries)
    
    # Parse tweets
    parsed_tweets = map(tweet -> get(get(get(tweet, :content, Dict()),
                                       :itemContent, Dict()),
                                   :tweet_results, Dict()).result,
                       tweets)

    return parsed_tweets
end

"""
    HomeLatestTimelineResponse

Type for the Home Latest Timeline response.
"""
struct HomeLatestTimelineResponse
    data::Union{Nothing,Dict{String,Any}}
end

export fetch_following_timeline, HomeLatestTimelineResponse

end # module 