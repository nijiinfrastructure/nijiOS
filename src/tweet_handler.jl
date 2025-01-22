module TweetHandler

using HTTP
using JSON3
using URIs
using Dates
using ..Types
using ..API
using ..APIv2
using ..Retry
using ..Auth: generate_oauth1_header
using Random
using SHA
using UUID

export get_tweet, get_tweets, send_tweet, create_thread, get_tweets_where, get_tweet_where, create_tweet

"""
    parse_tweet_response(response_body::String) -> Tweet

Parses the Twitter API response into a Tweet object.
"""
function parse_tweet_response(response_body::String)
    data = JSON3.read(response_body)
    tweet_data = data.data
    
    # Extract metrics
    metrics = if haskey(tweet_data, :public_metrics)
        TweetMetrics(
            get(tweet_data.public_metrics, :reply_count, 0),
            get(tweet_data.public_metrics, :retweet_count, 0),
            get(tweet_data.public_metrics, :like_count, 0),
            get(tweet_data.public_metrics, :quote_count, 0),
            get(tweet_data.public_metrics, :bookmark_count, 0)
        )
    else
        TweetMetrics()
    end
    
    # Extract references
    references = if haskey(tweet_data, :referenced_tweets)
        refs = tweet_data.referenced_tweets
        reply_to = nothing
        quoted = nothing
        retweeted = nothing
        
        for ref in refs
            if ref.type == "replied_to"
                reply_to = ref.id
            elseif ref.type == "quoted"
                quoted = ref.id
            elseif ref.type == "retweeted"
                retweeted = ref.id
            end
        end
        
        TweetReferences(reply_to, quoted, retweeted)
    else
        TweetReferences()
    end
    
    # Parse date
    created_at = if haskey(tweet_data, :created_at)
        DateTime(tweet_data.created_at[1:19], "yyyy-mm-ddTHH:MM:SS")
    else
        now()
    end
    
    # Create tweet
    return Tweet(
        tweet_data.id,
        tweet_data.text,
        tweet_data.author_id,
        created_at,
        metrics,
        references,
        get(tweet_data, :attachments, String[]),
        get(tweet_data, :lang, "unknown"),
        get(tweet_data, :possibly_sensitive, false),
        get(tweet_data, :source, "unknown")
    )
end

"""
    get_tweet(scraper::Scraper, tweet_id::String) -> Tweet

Retrieves a single tweet by its ID.

# Example
```julia
tweet = get_tweet(scraper, "1234567890")
```
"""
function get_tweet(scraper::Scraper, tweet_id::String)
    url = "https://api.twitter.com/2/tweets/$tweet_id" *
          "?expansions=author_id,referenced_tweets.id" *
          "&tweet.fields=created_at,public_metrics,lang,source,possibly_sensitive" *
          "&user.fields=username"
    
    headers = [
        "Authorization" => "Bearer $(ENV["TWITTER_BEARER_TOKEN"])",
        "Content-Type" => "application/json"
    ]
    
    @info "Fetching tweet" url headers
    
    response = HTTP.get(url, headers)
    return parse_tweet_response(String(response.body))
end

"""
    get_tweets(scraper::Scraper, username::String, limit::Int=100)

Retrieves tweets from a specific user.
"""
function get_tweets(scraper::Scraper, username::String, limit::Int=100)
    user_id = get_user_id_by_username(scraper, username)
    
    tweets = Tweet[]
    pagination_token = nothing
    
    while length(tweets) < limit
        check_rate_limit!(scraper, "tweets/user_timeline")
        
        query = Dict(
            "max_results" => min(100, limit - length(tweets)),
            "tweet.fields" => "created_at,author_id,conversation_id,entities,public_metrics"
        )
        
        if !isnothing(pagination_token)
            query["pagination_token"] = pagination_token
        end
        
        response = make_request(
            scraper,
            "GET",
            "$(API_V2)/users/$(user_id)/tweets",
            query=query
        )
        
        data = JSON.parse(String(response.body))
        
        # Parse and add tweets
        for tweet_data in get(data, "data", [])
            push!(tweets, parse_tweet(tweet_data))
        end
        
        # Update pagination token
        meta = get(data, "meta", Dict())
        pagination_token = get(meta, "next_token", nothing)
        
        if isnothing(pagination_token)
            break
        end
    end
    
    return tweets
end

"""
    send_tweet(scraper::Scraper, text::String; poll=nothing) -> Dict

Sends a new tweet using OAuth 1.0a and the latest API v2 endpoint.
"""
function send_tweet(scraper::Scraper, text::String; poll=nothing)
    url = "https://api.twitter.com/2/tweets"
    
    # OAuth 1.0a Headers with additional parameters
    params = Dict{String,String}(
        "status" => text,
        "tweet_mode" => "extended"
    )
    
    oauth_headers = generate_oauth1_header(
        "POST",
        url,
        params,
        ENV["TWITTER_API_KEY"],
        ENV["TWITTER_API_SECRET"],
        ENV["TWITTER_ACCESS_TOKEN"],
        ENV["TWITTER_ACCESS_SECRET"]
    )
    
    headers = [
        "Authorization" => oauth_headers,
        "Content-Type" => "application/json",
        "X-Client-UUID" => string(uuid4()),
        "Cache-Control" => "no-cache",
        "X-Tweet-Mode" => "extended"
    ]
    
    body = Dict(
        "text" => text,
        "reply" => Dict{String,Any}(),
        "quote_tweet_id" => nothing,
        "poll" => poll,
        "media" => Dict{String,Any}()
    )
    
    @info "Sending tweet" url headers body
    
    response = HTTP.post(url, headers, JSON3.write(body))
    
    @info "Raw API Response" String(response.body)
    
    return JSON3.read(response.body)
end

"""
    create_thread(scraper::Scraper, tweets::Vector{String})

Creates a thread from multiple tweets.
"""
function create_thread(scraper::Scraper, tweets::Vector{String})
    if isempty(tweets)
        throw(ArgumentError("Tweet list cannot be empty"))
    end
    
    thread_tweets = []
    previous_tweet_id = nothing
    
    for tweet_text in tweets
        options = TweetOptions(reply_to_tweet_id=previous_tweet_id)
        response = send_tweet(scraper, tweet_text, options)
        
        push!(thread_tweets, response["data"])
        previous_tweet_id = response["data"]["id"]
    end
    
    return thread_tweets
end

"""
    get_tweets_where(tweets::Vector{Tweet}, query::TweetQuery)::Vector{Tweet}

Filters tweets based on specific criteria.
"""
function get_tweets_where(tweets::Vector{Tweet}, query::TweetQuery)::Vector{Tweet}
    if query isa Function
        return filter(query, tweets)
    else
        return filter(tweet -> check_tweet_matches(tweet, query), tweets)
    end
end

"""
    get_tweet_where(tweets::Vector{Tweet}, query::TweetQuery)::Union{Tweet,Nothing}

Finds the first tweet that matches the criteria.
"""
function get_tweet_where(tweets::Vector{Tweet}, query::TweetQuery)::Union{Tweet,Nothing}
    if query isa Function
        return findfirst(query, tweets)
    else
        return findfirst(tweet -> check_tweet_matches(tweet, query), tweets)
    end
end

"""
    check_tweet_matches(tweet::Tweet, options::Dict{Symbol,Any})::Bool

Checks if a tweet matches specific criteria.
"""
function check_tweet_matches(tweet::Tweet, options::Dict{Symbol,Any})::Bool
    all(k -> getfield(tweet, k) == options[k], keys(options))
end

"""
    get_latest_tweet(scraper::Scraper, username::String; 
                    include_retweets::Bool=false, max::Int=1)::Union{Tweet,Nothing}

Gets the latest tweet from a user.
"""
function get_latest_tweet(scraper::Scraper, username::String; 
                         include_retweets::Bool=false, max::Int=1)::Union{Tweet,Nothing}
    tweets = get_tweets(scraper, username, max)
    
    if max == 1
        return first(tweets)
    else
        return get_tweet_where(tweets, Dict(:is_retweet => include_retweets))
    end
end

"""
    create_tweet(scraper::Scraper, text::String; 
                reply_to::Union{String,Nothing}=nothing,
                quote::Union{String,Nothing}=nothing) -> Tweet

Creates a new tweet using OAuth 2.0 PKCE Flow.
"""
function create_tweet(scraper::Scraper, text::String;
                     reply_to::Union{String,Nothing}=nothing,
                     quote::Union{String,Nothing}=nothing)
    
    # Check text length
    if length(text) > 280
        error("Tweet text cannot be longer than 280 characters")
    end
    
    # OAuth 2.0 PKCE Setup
    code_verifier = base64encode(Random.randstring(32))
    code_challenge = base64encode(sha256(code_verifier))
    
    # OAuth 2.0 Authorization URL
    auth_url = "https://twitter.com/i/oauth2/authorize"
    auth_params = Dict(
        "response_type" => "code",
        "client_id" => ENV["TWITTER_CLIENT_ID"],
        "redirect_uri" => ENV["TWITTER_REDIRECT_URI"],
        "scope" => "tweet.read tweet.write users.read offline.access",
        "state" => base64encode(Random.randstring(16)),
        "code_challenge" => code_challenge,
        "code_challenge_method" => "S256"
    )
    
    # Debug output
    @info "Authorization URL" auth_url auth_params
    
    println("\nPlease open this URL in your browser:")
    println("$auth_url?$(URIs.escapeuri(auth_params))")
    println("\nAfter authorization, you will be redirected to the Redirect URI.")
    println("Please enter the 'code' parameter from the Redirect URL:")
    
    auth_code = readline()
    
    # Token Request with Authorization Code
    token_url = "https://api.twitter.com/2/oauth2/token"
    
    # Basic Auth for Token Request
    auth_string = base64encode("$(ENV["TWITTER_CLIENT_ID"]):$(ENV["TWITTER_CLIENT_SECRET"])")
    
    token_headers = [
        "Authorization" => "Basic $auth_string",
        "Content-Type" => "application/x-www-form-urlencoded"
    ]
    
    token_body = HTTP.Form([
        "grant_type" => "authorization_code",
        "code" => auth_code,
        "redirect_uri" => "http://127.0.0.1:3000/callback",
        "client_id" => ENV["TWITTER_CLIENT_ID"],
        "code_verifier" => code_verifier
    ])
    
    # Debug output
    @info "Requesting OAuth 2.0 token" token_url token_headers
    
    token_response = HTTP.post(token_url, token_headers, token_body)
    token_data = JSON3.read(token_response.body)
    
    # Create tweet with Access Token
    url = "https://api.twitter.com/2/tweets"
    headers = [
        "Authorization" => "Bearer $(token_data.access_token)",
        "Content-Type" => "application/json"
    ]
    
    body = Dict{String,Any}("text" => text)
    if reply_to !== nothing
        body["reply"] = Dict{String,Any}(
            "in_reply_to_tweet_id" => reply_to
        )
    end
    if quote !== nothing
        body["quote_tweet_id"] = quote
    end
    
    # Debug output
    @info "Creating tweet" url body
    
    response = HTTP.post(url, headers, JSON3.write(body))
    
    # Parse Response
    data = JSON3.read(response.body).data
    
    return Tweet(
        data.id,
        data.text,
        get(data, :author_id, "unknown"),
        now(),
        TweetMetrics(),
        TweetReferences(reply_to, quote, nothing),
        String[],
        get(data, :lang, "unknown"),
        get(data, :possibly_sensitive, false),
        "API v2"
    )
end

"""
    post_tweet(scraper::Scraper, text::String) -> Dict

Posts a tweet using OAuth 2.0 User Access Token.
"""
function post_tweet(scraper::Scraper, text::String)
    # OAuth 2.0 Token Request
    token_url = "https://api.twitter.com/2/oauth2/token"
    
    # Basic Auth for Token Request
    auth_string = base64encode("$(ENV["TWITTER_CLIENT_ID"]):$(ENV["TWITTER_CLIENT_SECRET"])")
    
    token_headers = [
        "Authorization" => "Basic $auth_string",
        "Content-Type" => "application/x-www-form-urlencoded"
    ]
    
    token_body = HTTP.Form([
        "grant_type" => "client_credentials",
        "client_id" => ENV["TWITTER_CLIENT_ID"]
    ])
    
    # Debug output
    @info "Requesting OAuth 2.0 token" token_url token_headers
    
    token_response = HTTP.post(token_url, token_headers, token_body)
    token_data = JSON3.read(token_response.body)
    
    # Create tweet with Access Token
    url = "https://api.twitter.com/2/tweets"
    headers = [
        "Authorization" => "Bearer $(token_data.access_token)",
        "Content-Type" => "application/json"
    ]
    
    body = Dict{String,Any}("text" => text)
    
    # Debug output
    @info "Creating tweet" url headers body
    
    response = HTTP.post(url, headers, JSON3.write(body))
    return JSON3.read(response.body)
end

function generate_oauth1_header(method::String, url::String, params::Dict{String,String}, 
                              api_key::String, api_secret::String, 
                              access_token::String, access_secret::String)
    # Timestamp and Nonce
    oauth_timestamp = string(floor(Int, time()))
    oauth_nonce = base64encode(Random.randstring(32))
    
    # OAuth Parameters
    oauth_params = Dict{String,String}(
        "oauth_consumer_key" => api_key,
        "oauth_nonce" => oauth_nonce,
        "oauth_signature_method" => "HMAC-SHA1",
        "oauth_timestamp" => oauth_timestamp,
        "oauth_token" => access_token,
        "oauth_version" => "1.0"
    )
    
    # Combine parameters
    all_params = merge(params, oauth_params)
    
    # Sort and encode parameters
    param_string = join(sort([string(k, "=", URIs.escapeuri(v)) for (k,v) in all_params]), "&")
    
    # Create base string
    base_string = join([
        method,
        URIs.escapeuri(url),
        URIs.escapeuri(param_string)
    ], "&")
    
    # Create signing key
    signing_key = join([
        URIs.escapeuri(api_secret),
        URIs.escapeuri(access_secret)
    ], "&")
    
    # Generate signature
    oauth_signature = base64encode(hmac_sha1(signing_key, base_string))
    oauth_params["oauth_signature"] = oauth_signature
    
    # Create header string
    header_params = ["$k=\"$(URIs.escapeuri(v))\"" for (k,v) in sort(collect(oauth_params))]
    return "OAuth " * join(header_params, ", ")
end

end # module 