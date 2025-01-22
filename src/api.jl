using HTTP
using JSON
using Base64
using JSON3
using Dates
using URIs
using ..Retry: retry_with_backoff
using ..TweetTypes  # Import TweetTypes module
using ..Types
using ..TwitterRateLimiter
using ..Utils: perform_request
using ..Constants: API_ENDPOINTS, DEFAULT_HEADERS

"""
    TwitterAPIError

API error type
"""
struct TwitterAPIError <: Exception
    code::Int
    message::String
end

"""
    TwitterRateLimitError

Extended error type for rate limiting
"""
struct TwitterRateLimitError <: Exception
    reset_at::DateTime
    message::String
end

"""
    TwitterAuthenticationError

Error type for authentication failures
"""
struct TwitterAuthenticationError <: Exception
    message::String
end

# Basic API types
abstract type TwitterResponse end

struct SearchResponse <: TwitterResponse
    tweets::Vector{Tweet}
    next_token::Union{String,Nothing}
    previous_token::Union{String,Nothing}
end

struct TimelineResponse <: TwitterResponse
    tweets::Vector{Tweet}
    next_cursor::Union{String,Nothing}
    previous_cursor::Union{String,Nothing}
end

struct TrendsResponse <: TwitterResponse
    trends::Vector{String}
end

# API Configuration
const API_BASE = "https://api.twitter.com"
const API_VERSION = "2"

module API

using ..Retry: retry_with_backoff  # Important: .. for Parent Module

export make_request, TwitterResponse

"""
    TwitterResponse

Represents a response from the Twitter API.
"""
struct TwitterResponse
    status::Int
    headers::Dict{String, String}
    body::String
end

"""
    make_request(scraper, method, url, headers=[], body=nothing) -> HTTP.Response

Performs an HTTP request with rate limiting and authentication.
"""
function make_request(scraper::Scraper, method::String, url::String; headers=Dict(), body=nothing, query=Dict())
    # Check rate limits before making the request
    check_rate_limit!(scraper, url)

    # Create request options
    options = HTTP.RequestOptions(
        headers = headers,
        body = body,
        query = query
    )

    # Enhanced error handling with retries
    response = retry_with_backoff() do
        try
            HTTP.request(method, url, options)
        catch e
            if isa(e, HTTP.ExceptionRequest.StatusError)
                status_code = e.status
                if status_code == 401
                    throw(AuthenticationError("Authentication failed", status_code, e.response))
                elseif status_code == 429
                    reset_time = parse(Int, get(e.response.headers, "x-rate-limit-reset", "0"))
                    throw(RateLimitError("Rate limit exceeded", DateTime(unix2datetime(reset_time)), 0, 0))
                else
                    throw(APIError("API request failed", status_code, e.response))
                end
            else
                rethrow(e)
            end
        end
    end

    # Update rate limit information
    update_rate_limit!(scraper, url, response.headers)

    return response
end

"""
    get_endpoint_from_url(url::String) -> String

Extracts the endpoint name from a URL.
"""
function get_endpoint_from_url(url::String)
    uri = URI(url)
    path_parts = split(uri.path, '/')
    return join(filter(!isempty, path_parts[1:min(3, end)]), "/")
end

"""
    make_request(scraper::Scraper, method::String, url::String; 
                query::Dict{String,Any}=Dict(), body::Union{Dict,Nothing}=nothing)

Executes an API request and handles errors and rate limiting.
"""
function make_request(scraper::Scraper, method::String, url::String;
                     query::Dict{String,Any}=Dict(), 
                     body::Union{Dict,Nothing}=nothing)
    
    if !is_logged_in(scraper)
        throw(TwitterAuthenticationError("Not logged in"))
    end
    
    headers = prepare_headers(scraper)
    full_url = build_url(url, query)
    
    try
        response = if !isnothing(body)
            HTTP.request(method, full_url, 
                headers=headers,
                body=JSON.json(body),
                client=scraper.client)
        else
            HTTP.request(method, full_url, 
                headers=headers,
                client=scraper.client)
        end
        
        # Rate Limit Headers verarbeiten
        update_rate_limits!(scraper, response.headers)
        
        return TwitterResponse(
            response.status,
            Dict(response.headers),
            String(response.body)
        )
    catch e
        if isa(e, HTTP.StatusError)
            error_data = try
                JSON.parse(String(e.response.body))
            catch
                Dict("message" => "Unknown error")
            end
            
            if e.status == 429  # Rate Limit
                reset_time = try
                    unix2datetime(parse(Int, e.response.headers["x-rate-limit-reset"]))
                catch
                    now() + Minute(15)  # Fallback
                end
                throw(TwitterRateLimitError(reset_time, error_data["message"]))
            end
            
            throw(TwitterAPIError(e.status, error_data["message"]))
        end
        rethrow(e)
    end
end

"""
    prepare_headers(scraper::Scraper)

Prepares the HTTP headers for a request.
"""
function prepare_headers(scraper::Scraper)
    headers = [
        "Content-Type" => "application/json",
        "User-Agent" => "TwitterClient.jl/0.1.0"
    ]
    
    if !isnothing(scraper.auth.bearer_token)
        push!(headers, "Authorization" => "Bearer $(scraper.auth.bearer_token)")
    end
    
    if !isempty(scraper.auth.cookies)
        cookie_string = join(["$k=$v" for (k,v) in scraper.auth.cookies], "; ")
        push!(headers, "Cookie" => cookie_string)
    end
    
    return headers
end

"""
    build_url(base_url::String, query::Dict{String,Any})

Builds a URL with query parameters.
"""
function build_url(base_url::String, query::Dict{String,Any})
    if isempty(query)
        return base_url
    end
    
    query_string = join(["$k=$(HTTP.escapeuri(string(v)))" 
                        for (k,v) in query], "&")
    return "$base_url?$query_string"
end

"""
    update_rate_limits!(scraper::Scraper, headers::Vector{Pair{String,String}})

Aktualisiert die Rate-Limit-Informationen aus den Response-Headers.
"""
function update_rate_limits!(scraper::Scraper, headers::Vector{Pair{String,String}})
    headers_dict = Dict(headers)
    
    if haskey(headers_dict, "x-rate-limit-limit") &&
       haskey(headers_dict, "x-rate-limit-remaining") &&
       haskey(headers_dict, "x-rate-limit-reset")
        
        endpoint = get_endpoint_from_headers(headers_dict)
        
        scraper.rate_limiter.endpoints[endpoint] = RateLimit(
            parse(Int, headers_dict["x-rate-limit-limit"]),
            parse(Int, headers_dict["x-rate-limit-remaining"]),
            unix2datetime(parse(Int, headers_dict["x-rate-limit-reset"]))
        )
    end
end

"""
    search_tweets(auth::TwitterAuth, query::String; max_results::Int=10) -> SearchResponse

Searches for tweets based on a search query.
"""
function search_tweets(auth::TwitterAuth, query::String; max_results::Int=10)
    endpoint = "/2/tweets/search/recent"
    params = Dict(
        "query" => query,
        "max_results" => max_results,
        "tweet.fields" => "created_at,author_id,conversation_id,public_metrics"
    )
    
    response = make_request(auth, "GET", endpoint, params)
    parse_search_response(response)
end

"""
    get_trends(auth::TwitterAuth) -> TrendsResponse

Get the latest Twitter trends.
"""
function get_trends(auth::TwitterAuth)
    endpoint = "/2/trends/place"
    params = Dict("id" => "1") # 1 = Weltweit
    
    response = make_request(auth, "GET", endpoint, params)
    parse_trends_response(response)
end

"""
    get_user_timeline(auth::TwitterAuth, user_id::String; max_results::Int=10) -> TimelineResponse

Gets the timeline of a specific user.
"""
function get_user_timeline(auth::TwitterAuth, user_id::String; max_results::Int=10)
    url = replace(API_ENDPOINTS["USER_TWEETS"], ":id" => user_id)
    headers = copy(DEFAULT_HEADERS)
    params = Dict(
        "max_results" => max_results,
        "tweet.fields" => "created_at,author_id,conversation_id,public_metrics"
    )
    
    response = make_request(auth, "GET", url, headers, params)
    parse_timeline_response(response)
end

function make_request(auth::TwitterAuth, method::String, endpoint::String, params::Dict)
    url = "$(API_BASE)$(endpoint)"
    headers = prepare_headers(auth)
    
    response = HTTP.request(
        method,
        url,
        headers,
        query=params,
        status_exception=false
    )
    
    if response.status != 200
        error("API request failed with status $(response.status)")
    end
    
    JSON3.read(response.body)
end

function prepare_headers(auth::TwitterAuth)
    [
        "Authorization" => "Bearer $(auth.bearer_token)",
        "Content-Type" => "application/json"
    ]
end

# Response Parser
function parse_search_response(response::JSON3.Object)
    tweets = [parse_tweet(t) for t in response.data]
    next_token = get(response, :next_token, nothing)
    previous_token = get(response, :previous_token, nothing)
    
    SearchResponse(tweets, next_token, previous_token)
end

function parse_timeline_response(response::JSON3.Object)
    tweets = [parse_tweet(t) for t in response.data]
    next_cursor = get(response, :next_token, nothing)
    previous_cursor = get(response, :previous_token, nothing)
    
    TimelineResponse(tweets, next_cursor, previous_cursor)
end

function parse_trends_response(response::JSON3.Object)
    trends = String[trend.name for trend in response[1].trends]
    TrendsResponse(trends)
end

function parse_tweet(tweet_data::JSON3.Object)
    Tweet(
        tweet_data.id,
        tweet_data.text,
        DateTime(tweet_data.created_at),
        tweet_data.author_id,
        tweet_data.conversation_id,
        get(tweet_data, :in_reply_to_user_id, nothing),
        tweet_data.lang,
        Dict{String,Int}(tweet_data.public_metrics)
    )
end

export Tweet, SearchResponse, TimelineResponse, TrendsResponse,
       search_tweets, get_trends, get_user_timeline 
end # module 