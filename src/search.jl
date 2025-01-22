module TwitterSearch

using ..TwitterAPI
using HTTP
using JSON3
using Dates

"""
Search modes for Twitter searches
"""
@enum SearchMode begin
    Top
    Latest
    Photos
    Videos
    Users
end

"""
    search_tweets(scraper::Scraper, query::String, max_tweets::Int, 
                 search_mode::SearchMode=Top) -> Channel{Tweet}

Searches for tweets and returns a channel that streams the found tweets.
"""
function search_tweets(scraper::Scraper, query::String, max_tweets::Int, 
                      search_mode::SearchMode=Top)
    Channel{Tweet}(; ctype=Tweet, csize=32) do channel
        cursor = nothing
        n_tweets = 0
        
        while n_tweets < max_tweets
            response = fetch_search_tweets(
                scraper, 
                query, 
                min(50, max_tweets - n_tweets),
                search_mode,
                cursor
            )
            
            for tweet in response.tweets
                put!(channel, tweet)
                n_tweets += 1
                if n_tweets >= max_tweets
                    break
                end
            end
            
            # Check if there are more results
            cursor = response.next_token
            if isnothing(cursor) || cursor == ""
                break
            end
        end
    end
end

"""
    search_profiles(scraper::Scraper, query::String, 
                   max_profiles::Int) -> Channel{Profile}

Searches for profiles and returns a channel that streams the found profiles.
"""
function search_profiles(scraper::Scraper, query::String, max_profiles::Int)
    Channel{Profile}(; ctype=Profile, csize=32) do channel
        cursor = nothing
        n_profiles = 0
        
        while n_profiles < max_profiles
            response = fetch_search_profiles(
                scraper,
                query,
                min(50, max_profiles - n_profiles),
                cursor
            )
            
            for profile in response.profiles
                put!(channel, profile)
                n_profiles += 1
                if n_profiles >= max_profiles
                    break
                end
            end
            
            cursor = response.next_token
            if isnothing(cursor) || cursor == ""
                break
            end
        end
    end
end

"""
    fetch_search_tweets(scraper::Scraper, query::String, max_tweets::Int,
                       search_mode::SearchMode, cursor::Union{String,Nothing}
                       ) -> QueryTweetsResponse

Performs a single search query for tweets.
"""
function fetch_search_tweets(scraper::Scraper, query::String, max_tweets::Int,
                           search_mode::SearchMode, cursor::Union{String,Nothing}=nothing)
    timeline = get_search_timeline(scraper, query, max_tweets, search_mode, cursor)
    parse_search_timeline_tweets(timeline)
end

"""
    fetch_search_profiles(scraper::Scraper, query::String, max_profiles::Int,
                         cursor::Union{String,Nothing}) -> QueryProfilesResponse

Performs a single search query for profiles.
"""
function fetch_search_profiles(scraper::Scraper, query::String, max_profiles::Int,
                             cursor::Union{String,Nothing}=nothing)
    timeline = get_search_timeline(scraper, query, max_profiles, SearchMode.Users, cursor)
    parse_search_timeline_users(timeline)
end

"""
    get_search_timeline(scraper::Scraper, query::String, max_items::Int,
                       search_mode::SearchMode, cursor::Union{String,Nothing}
                       ) -> SearchTimeline

Retrieves search results from the Twitter API.
"""
function get_search_timeline(scraper::Scraper, query::String, max_items::Int,
                           search_mode::SearchMode, cursor::Union{String,Nothing}=nothing)
    
    if !is_logged_in(scraper)
        throw(TwitterAuthenticationError("Scraper is not logged in for search."))
    end

    max_items = min(max_items, 50)
    
    variables = Dict{String,Any}(
        "rawQuery" => query,
        "count" => max_items,
        "querySource" => "typed_query",
        "product" => get_search_product(search_mode)
    )
    
    if !isnothing(cursor) && cursor != ""
        variables["cursor"] = cursor
    end
    
    features = Dict{String,Any}(
        "longform_notetweets_inline_media_enabled" => true,
        "responsive_web_enhance_cards_enabled" => false,
        "responsive_web_media_download_video_enabled" => false,
        "responsive_web_twitter_article_tweet_consumption_enabled" => false,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled" => true,
        "interactive_text_enabled" => false,
        "responsive_web_text_conversations_enabled" => false,
        "vibe_api_enabled" => false
    )
    
    field_toggles = Dict{String,Any}(
        "withArticleRichContentState" => false
    )
    
    params = HTTP.escapeuri(Dict(
        "features" => JSON3.write(features),
        "fieldToggles" => JSON3.write(field_toggles),
        "variables" => JSON3.write(variables)
    ))
    
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/graphql/gkjsKepM6gl_HmFWoWKfgg/SearchTimeline?$params"
    )
    
    return response
end

"""
    get_search_product(mode::SearchMode) -> String

Converts the SearchMode to the corresponding API parameter.
"""
function get_search_product(mode::SearchMode)
    if mode == Latest
        return "Latest"
    elseif mode == Photos
        return "Photos"
    elseif mode == Videos
        return "Videos"
    elseif mode == Users
        return "People"
    else
        return "Top"
    end
end

export SearchMode, search_tweets, search_profiles

end # module 