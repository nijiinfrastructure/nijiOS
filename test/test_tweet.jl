using DotEnv
using TwitterAuth

# Load .env file
DotEnv.load()

# Send test tweet
try
    auth = TwitterUserAuth(ENV["TWITTER_BEARER_TOKEN"])
    
    # Login with existing tokens
    auth.cookies["auth_token"] = ENV["TWITTER_AUTH_TOKEN"]
    auth.cookies["ct0"] = ENV["TWITTER_CSRF_TOKEN"]
    
    # Set OAuth v1.1 Credentials
    auth.api_key = ENV["TWITTER_API_KEY"]
    auth.api_secret = ENV["TWITTER_API_SECRET"]
    auth.access_token = ENV["TWITTER_ACCESS_TOKEN"]
    auth.access_secret = ENV["TWITTER_ACCESS_SECRET"]
    
    # Tweet text
    text = "Test Tweet created with #Julia on $(Dates.format(now(), "dd.mm.yyyy HH:MM")) 🚀"
    
    response = post_tweet(auth, text)
    println("\n✓ Tweet successfully sent:")
    println(JSON3.pretty(response))
catch e
    println("\n✗ Error sending tweet:")
    println(e)
end 