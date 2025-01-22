module TwitterTimelineList

using ..TwitterTypes
using ..TwitterTimelineTypes
using ..TwitterTimelineV2

"""
    parse_list_timeline_tweets(timeline::ListTimeline)::QueryTweetsResponse

Parses tweets from a list timeline.
"""
function parse_list_timeline_tweets(timeline::ListTimeline)::QueryTweetsResponse
    bottom_cursor = nothing
    top_cursor = nothing
    tweets = Tweet[]
    
    # Extract instructions from timeline
    instructions = get(get(get(get(timeline.data, :list, Dict()),
                              :tweets_timeline, Dict()),
                         :timeline, Dict()),
                    :instructions, [])
    
    for instruction in instructions
        entries = get(instruction, :entries, [])
        
        for entry in entries
            entry_content = get(entry, :content, nothing)
            if isnothing(entry_content)
                continue
            end
            
            # Process cursor
            if get(entry_content, :cursorType, nothing) == "Bottom"
                bottom_cursor = get(entry_content, :value, nothing)
                continue
            elseif get(entry_content, :cursorType, nothing) == "Top"
                top_cursor = get(entry_content, :value, nothing)
                continue
            end
            
            # Validate tweet ID
            id_str = entry.entryId
            if !startswith(id_str, "tweet-") && !startswith(id_str, "list-conversation-")
                continue
            end
            
            # Process tweet content
            if !isnothing(get(entry_content, :itemContent, nothing))
                parse_and_push(tweets, entry_content.itemContent, id_str)
            elseif !isnothing(get(entry_content, :items, nothing))
                for content_item in entry_content.items
                    if !isnothing(get(content_item, :item, nothing)) &&
                       !isnothing(get(content_item.item, :itemContent, nothing)) &&
                       !isnothing(get(content_item, :entryId, nothing))
                        parse_and_push(
                            tweets,
                            content_item.item.itemContent,
                            split(content_item.entryId, "tweet-")[2]
                        )
                    end
                end
            end
        end
    end
    
    return QueryTweetsResponse(tweets, bottom_cursor, top_cursor)
end

"""
    ListTimelineResponse

Type for a list timeline response.
"""
struct ListTimelineResponse
    data::Union{Nothing,Dict{String,Any}}
    list::Union{Nothing,Dict{String,Any}}
    tweets_timeline::Union{Nothing,Dict{String,Any}}
    timeline::Union{Nothing,Dict{String,Any}}
    instructions::Vector{Dict{String,Any}}
end

"""
    fetch_list_timeline(list_id::String, count::Int, cursor::Union{String,Nothing}, 
                       scraper::Scraper)::ListTimelineResponse

Fetches the timeline of a specific list.
"""
function fetch_list_timeline(list_id::String, count::Int, cursor::Union{String,Nothing}, 
                           scraper::Scraper)::ListTimelineResponse
    # Variables for GraphQL query
    variables = Dict(
        "listId" => list_id,
        "count" => count,
        "cursor" => cursor
    )

    # Features for GraphQL query
    features = Dict(
        "rweb_lists_timeline_redesign_enabled" => true,
        "responsive_web_graphql_exclude_directive_enabled" => true,
        "verified_phone_label_enabled" => false,
        "creator_subscriptions_tweet_preview_api_enabled" => true,
        "responsive_web_graphql_timeline_navigation_enabled" => true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled" => false,
        "tweetypie_unmention_optimization_enabled" => true,
        "responsive_web_edit_tweet_api_enabled" => true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled" => true,
        "view_counts_everywhere_api_enabled" => true,
        "longform_notetweets_consumption_enabled" => true,
        "tweet_awards_web_tipping_enabled" => false,
        "freedom_of_speech_not_reach_fetch_enabled" => true,
        "standardized_nudges_misinfo" => true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled" => true,
        "longform_notetweets_rich_text_read_enabled" => true,
        "longform_notetweets_inline_media_enabled" => true,
        "responsive_web_enhance_cards_enabled" => false
    )

    # Execute GraphQL query
    response = make_request(
        scraper,
        "GET",
        "https://x.com/i/api/graphql/BbGLL1BPmAcVhyPmG3txpQ/ListLatestTweetsTimeline";
        query=Dict(
            "variables" => JSON3.write(variables),
            "features" => JSON3.write(features)
        )
    )

    if !response.success
        throw(response.error)
    end

    return ListTimelineResponse(response.data)
end

export parse_list_timeline_tweets, ListTimelineResponse, fetch_list_timeline

end # module 