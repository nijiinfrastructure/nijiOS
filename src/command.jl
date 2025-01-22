module TwitterCommand

using ..TwitterScraper
using ..TwitterTypes
using ..TwitterAuth
using JSON3
using REPL

# Global Constants
const PLATFORM_NODE = !isnothing(Base.find_package("Node"))
const PLATFORM_NODE_JEST = false

"""
    Scraper

Global scraper instance
"""
const scraper = Scraper()

"""
    login_and_save_cookies()

Logs in and saves cookies for future sessions.
"""
function login_and_save_cookies()
    try
        # Login with credentials from environment variables
        login(scraper,
              ENV["TWITTER_USERNAME"],
              ENV["TWITTER_PASSWORD"],
              get(ENV, "TWITTER_EMAIL", nothing))

        # Get current session cookies
        cookies = get_cookies(scraper)

        # Save cookies as JSON
        open(joinpath(@__DIR__, "cookies.json"), "w") do io
            JSON3.write(io, cookies)
        end

        println("Logged in and cookies saved.")
    catch e
        @error "Error during login:" exception=e
    end
end

"""
    load_cookies()

Loads cookies from the JSON file.
"""
function load_cookies()
    try
        # Read cookies from file
        cookies_data = open(joinpath(@__DIR__, "cookies.json")) do io
            JSON3.read(io, String)
        end
        cookies_array = JSON3.read(cookies_data)

        # Convert cookies to correct format
        cookie_strings = map(cookies_array) do cookie
            "$(cookie.key)=$(cookie.value); Domain=$(cookie.domain); Path=$(cookie.path); " *
            "$(cookie.secure ? "Secure; " : "")" *
            "$(cookie.httpOnly ? "HttpOnly; " : "")" *
            "SameSite=$(get(cookie, :sameSite, "Lax"))"
        end

        # Set cookies for current session
        set_cookies(scraper, cookie_strings)

        println("Cookies loaded from file.")
    catch e
        @error "Error loading cookies:" exception=e
    end
end

"""
    ensure_authenticated()

Ensures that the scraper is authenticated.
"""
function ensure_authenticated()
    cookie_path = joinpath(@__DIR__, "cookies.json")
    if isfile(cookie_path)
        # Load cookies if file exists
        load_cookies()
        println("You are already logged in.")
    else
        # Login if no cookies present
        login_and_save_cookies()
    end
end

"""
    send_tweet_command(text::String, media_files::Vector{String}=String[], 
                      reply_to_tweet_id::Union{String,Nothing}=nothing)::Union{String,Nothing}

Sends a tweet with optional media attachments.
"""
function send_tweet_command(text::String, media_files::Vector{String}=String[], 
                          reply_to_tweet_id::Union{String,Nothing}=nothing)::Union{String,Nothing}
    try
        media_data = nothing

        if !isempty(media_files)
            # Prepare media
            media_data = map(media_files) do file_path
                abs_path = abspath(joinpath(@__DIR__, file_path))
                buffer = read(abs_path)
                ext = lowercase(splitext(file_path)[2])
                media_type = get_media_type(ext)
                Dict(:data => buffer, :media_type => media_type)
            end
        end

        # Send tweet
        response = send_tweet(scraper, text, reply_to_tweet_id, media_data)
        
        # Extract tweet ID from response
        response_data = JSON3.read(String(response.body))
        tweet_id = get(get(get(get(response_data, :data, Dict()),
                              :create_tweet, Dict()),
                          :tweet_results, Dict()),
                      :rest_id, nothing)

        if !isnothing(tweet_id)
            println("Tweet sent: \"$text\" (ID: $tweet_id)")
            return tweet_id
        else
            @error "Tweet ID not found in response."
            return nothing
        end
    catch e
        @error "Error sending tweet:" exception=e
        return nothing
    end
end

"""
    get_media_type(ext::String)::String

Determines the media type based on file extension.
"""
function get_media_type(ext::String)::String
    media_types = Dict(
        ".jpg" => "image/jpeg",
        ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        ".gif" => "image/gif",
        ".mp4" => "video/mp4"
    )
    
    get(media_types, ext, "application/octet-stream")
end

"""
    get_replies_to_tweet(tweet_id::String)::Vector{Tweet}

Retrieves replies to a specific tweet.
"""
function get_replies_to_tweet(tweet_id::String)::Vector{Tweet}
    replies = Tweet[]
    try
        # Construct search query for replies
        query = "to:$(ENV["TWITTER_USERNAME"]) conversation_id:$tweet_id"
        max_replies = 100
        search_mode = 1  # SearchMode.Latest

        # Fetch replies
        for tweet in search_tweets(scraper, query, max_replies, search_mode)
            # Check if tweet is a direct reply
            if tweet.in_reply_to_status_id == tweet_id
                push!(replies, tweet)
            end
        end

        println("Found $(length(replies)) replies to tweet ID $tweet_id.")
    catch e
        @error "Error fetching replies:" exception=e
    end
    return replies
end

"""
    reply_to_tweet(tweet_id::String, text::String)

Replies to a specific tweet.
"""
function reply_to_tweet(tweet_id::String, text::String)
    try
        # Empty array for media_files, tweet_id as reply_to
        reply_id = send_tweet_command(text, String[], tweet_id)

        if !isnothing(reply_id)
            println("Reply sent (ID: $reply_id).")
        end
    catch e
        @error "Error sending reply:" exception=e
    end
end

"""
    get_photos_from_tweet(tweet_id::String)

Retrieves photos from a specific tweet.
"""
function get_photos_from_tweet(tweet_id::String)
    try
        # Fetch tweet by ID
        tweet = get_tweet(scraper, tweet_id)

        # Check if tweet exists and contains photos
        if !isnothing(tweet) && !isempty(tweet.photos)
            println("Found $(length(tweet.photos)) photo(s) in tweet ID $tweet_id:")
            # Output photo URLs
            for (i, photo) in enumerate(tweet.photos)
                println("Photo $i: $(photo.url)")
            end
        else
            println("No photos found in specified tweet.")
        end
    catch e
        @error "Error fetching tweet:" exception=e
    end
end

export scraper, ensure_authenticated, send_tweet_command, get_replies_to_tweet,
       reply_to_tweet, get_photos_from_tweet

end # module 