"""
Twitter API v2 Implementation
"""

using HTTP
using JSON3
using Dates
using Base64
using URIs
using ..Retry
using ..Types
using ..TwitterRateLimiter
using ..Auth: generate_oauth_header

# API Configuration for v2
const API_V2 = "https://api.twitter.com/2"

module APIv2

export make_request_v2, get_endpoint_from_url

"""
    make_request_v2(scraper, method, url, headers=[], body=nothing) -> HTTP.Response

Performs an HTTP request against the Twitter API v2 with Bearer Token authentication.
"""
function make_request_v2(scraper::Scraper, method::String, url::String, headers=[], body=nothing)
    # Check rate limiting
    endpoint = get_endpoint_from_url(url)
    check_rate_limit(scraper.rate_limiter, endpoint)
    
    # Get Bearer Token
    bearer_token = get(ENV, "TWITTER_BEARER_TOKEN", "")
    if isempty(bearer_token)
        error("TWITTER_BEARER_TOKEN is not set")
    end
    
    # Prepare headers
    all_headers = [
        "Authorization" => "Bearer $bearer_token",
        "Content-Type" => "application/json",
        headers...
    ]
    
    # Debug output
    @debug "Making request to $url"
    @debug "Using headers: $(filter(h -> h.first != "Authorization", all_headers))"
    
    # Execute request
    response = try
        if body === nothing
            HTTP.request(method, url, all_headers)
        else
            HTTP.request(method, url, all_headers, JSON3.write(body))
        end
    catch e
        if e isa HTTP.StatusError
            @error "API request failed" status=e.status response=String(e.response.body)
        end
        rethrow(e)
    end
    
    # Update rate limit
    update_rate_limit(scraper.rate_limiter, endpoint, response)
    
    return response
end

"""
    get_endpoint_from_url(url::String) -> String

Extracts the endpoint name from a URL for API v2.
"""
function get_endpoint_from_url(url::String)
    uri = URI(url)
    path_parts = split(uri.path, '/')
    # For v2 API we take the part after "v2"
    v2_index = findfirst(x -> x == "v2", path_parts)
    if v2_index !== nothing
        return join(path_parts[v2_index:min(v2_index+2, end)], "/")
    end
    return join(filter(!isempty, path_parts[1:min(3, end)]), "/")
end

end # module

"""
    send_tweet_v2(scraper::Scraper, text::String;
                  reply_to::Union{String,Nothing}=nothing,
                  quote_tweet_id::Union{String,Nothing}=nothing,
                  poll::Union{Dict,Nothing}=nothing)

Sendet einen Tweet über die Twitter API v2.
"""
function send_tweet_v2(scraper::Scraper, text::String;
                      reply_to::Union{String,Nothing}=nothing,
                      quote_tweet_id::Union{String,Nothing}=nothing,
                      poll::Union{Dict,Nothing}=nothing)
    
    body = Dict("text" => text)
    
    if !isnothing(reply_to)
        body["reply"] = Dict("in_reply_to_tweet_id" => reply_to)
    end
    
    if !isnothing(quote_tweet_id)
        body["quote_tweet_id"] = quote_tweet_id
    end
    
    if !isnothing(poll)
        body["poll"] = poll
    end
    
    response = make_request_v2(
        scraper,
        "POST",
        "$(API_V2)/tweets",
        body=body
    )
    
    return response.data
end

"""
    get_tweet_v2(scraper::Scraper, tweet_id::String; 
                 expansions::Vector{String}=String[])

Ruft einen Tweet über die Twitter API v2 ab.
"""
function get_tweet_v2(scraper::Scraper, tweet_id::String;
                     expansions::Vector{String}=String[])
    
    query = Dict{String,Any}()
    if !isempty(expansions)
        query["expansions"] = join(expansions, ",")
    end
    
    # Füge Standard-Tweet-Felder hinzu
    query["tweet.fields"] = join([
        "created_at",
        "author_id",
        "conversation_id",
        "in_reply_to_user_id",
        "public_metrics",
        "entities",
        "referenced_tweets"
    ], ",")
    
    response = make_request_v2(
        scraper,
        "GET",
        "$(API_V2)/tweets/$(tweet_id)",
        query=query
    )
    
    return response.data
end

"""
    get_tweets_v2(scraper::Scraper, tweet_ids::Vector{String})

Ruft mehrere Tweets über die Twitter API v2 ab.
"""
function get_tweets_v2(scraper::Scraper, tweet_ids::Vector{String})
    query = Dict{String,Any}(
        "ids" => join(tweet_ids, ","),
        "tweet.fields" => join([
            "created_at",
            "author_id",
            "conversation_id",
            "in_reply_to_user_id",
            "public_metrics",
            "entities",
            "referenced_tweets"
        ], ",")
    )
    
    response = make_request_v2(
        scraper,
        "GET",
        "$(API_V2)/tweets",
        query=query
    )
    
    return response.data
end

"""
    get_user_tweets_v2(scraper::Scraper, user_id::String; 
                      max_results::Int=100,
                      pagination_token::Union{String,Nothing}=nothing)

Ruft die Tweets eines Benutzers über die Twitter API v2 ab.
"""
function get_user_tweets_v2(scraper::Scraper, user_id::String;
                          max_results::Int=100,
                          pagination_token::Union{String,Nothing}=nothing)
    
    query = Dict{String,Any}(
        "max_results" => max_results,
        "tweet.fields" => join([
            "created_at",
            "author_id",
            "conversation_id",
            "in_reply_to_user_id",
            "public_metrics",
            "entities",
            "referenced_tweets"
        ], ",")
    )
    
    if !isnothing(pagination_token)
        query["pagination_token"] = pagination_token
    end
    
    response = make_request_v2(
        scraper,
        "GET",
        "$(API_V2)/users/$(user_id)/tweets",
        query=query
    )
    
    return response.data
end

export send_tweet_v2, get_tweet_v2, get_tweets_v2, get_user_tweets_v2 