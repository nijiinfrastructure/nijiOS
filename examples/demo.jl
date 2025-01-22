using TwitterClient
using Dates
using Dotenv

# Load environment variables
Dotenv.config()

function main()
    println("Twitter Client Demo started...")
    
    # Initialize scraper and log in
    scraper = Scraper()
    
    try
        # Attempt login with credentials from ENV
        println("Attempting login...")
        login!(scraper, 
            ENV["TWITTER_USERNAME"],
            ENV["TWITTER_PASSWORD"],
            ENV["TWITTER_EMAIL"]
        )
        println("Login successful!")
        
        # 1. Send a simple tweet
        println("\n1. Sending a simple tweet")
        tweet_text = "Test tweet from TwitterClient.jl $(now())"
        response = send_tweet(scraper, tweet_text)
        tweet_id = response["data"]["id"]
        println("Tweet sent! ID: $tweet_id")
        
        # 2. Send a tweet with an image
        println("\n2. Sending a tweet with an image")
        # Create an example image or use an existing one
        test_image = "examples/test_image.jpg"
        media = upload_media(scraper, test_image, alt_text="Test image")
        options = TweetOptions(media_ids=[media.media_id])
        response = send_tweet(scraper, "Tweet with image test $(now())", options)
        println("Tweet with image sent! ID: $(response["data"]["id"])")
        
        # 3. Create a thread
        println("\n3. Creating a thread")
        thread_tweets = [
            "This is the start of a thread $(now())",
            "This is the second tweet in the thread",
            "And this is the last tweet in the thread!"
        ]
        thread = create_thread(scraper, thread_tweets)
        println("Thread created! $(length(thread)) tweets sent")
        
        # 4. Test Grok chat
        println("\n4. Testing Grok chat")
        messages = [GrokMessage(User, "What are the latest developments in AI?")]
        options = GrokChatOptions(return_search_results=true)
        chat_response = grok_chat(scraper, messages, options)
        println("Grok response received:")
        println(chat_response.message)
        
        if !isnothing(chat_response.web_results)
            println("\nSources:")
            for (i, result) in enumerate(chat_response.web_results)
                println("$i. $(result["title"])")
            end
        end
        
        # 5. Retrieve profile information
        println("\n5. Retrieving profile information")
        profile = get_profile(scraper, ENV["TWITTER_USERNAME"])
        println("Profile found:")
        println("Name: $(profile.name)")
        println("Followers: $(profile.followers_count)")
        println("Following: $(profile.following_count)")
        
        # 6. Search tweets
        println("\n6. Searching tweets")
        search_results = search_tweets(scraper, "AI development", Latest, 5)
        println("Found tweets:")
        for tweet in search_results
            println("- $(tweet.text)")
        end
        
    catch e
        if isa(e, TwitterRateLimitError)
            println("Rate limit reached. Reset at: $(e.reset_at)")
        elseif isa(e, TwitterAuthenticationError)
            println("Authentication error: $(e.message)")
        elseif isa(e, TwitterAPIError)
            println("API error ($(e.code)): $(e.message)")
        else
            println("Unexpected error: $e")
        end
    finally
        # Log out
        logout!(scraper)
        println("\nDemo finished.")
    end
end

# Execute script
main() 