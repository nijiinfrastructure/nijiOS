module TwitterTimelineAsync

using ..TwitterTypes
using ..TwitterProfile
using ..TwitterTimelineTypes

"""
    get_user_timeline(query::String, max_profiles::Int, fetch_func::Function)::Channel{Profile}

Generator for user timeline. Returns profiles in a channel.
"""
function get_user_timeline(query::String, max_profiles::Int, fetch_func::Function)::Channel{Profile}
    Channel{Profile}(; ctype=Profile, csize=32) do channel
        n_profiles = 0
        cursor = nothing
        consecutive_empty_batches = 0
        
        while n_profiles < max_profiles
            # Fetch batch
            batch = fetch_func(query, max_profiles, cursor)
            
            profiles = batch.profiles
            next = get(batch, :next, nothing)
            cursor = next
            
            # Count empty batches
            if isempty(profiles)
                consecutive_empty_batches += 1
                if consecutive_empty_batches > 5
                    break
                end
            else
                consecutive_empty_batches = 0
            end
            
            # Process profiles
            for profile in profiles
                if n_profiles < max_profiles
                    put!(channel, profile)
                else
                    break
                end
                n_profiles += 1
            end
            
            # Check if more pages are available
            if isnothing(next)
                break
            end
        end
    end
end

"""
    get_tweet_timeline(query::String, max_tweets::Int, fetch_func::Function)::Channel{Tweet}

Generator for tweet timeline. Returns tweets in a channel.
"""
function get_tweet_timeline(query::String, max_tweets::Int, fetch_func::Function)::Channel{Tweet}
    Channel{Tweet}(; ctype=Tweet, csize=32) do channel
        n_tweets = 0
        cursor = nothing
        
        while n_tweets < max_tweets
            # Fetch batch
            batch = fetch_func(query, max_tweets, cursor)
            
            tweets = batch.tweets
            next = get(batch, :next, nothing)
            
            # Break if no more tweets
            if isempty(tweets)
                break
            end
            
            # Process tweets
            for tweet in tweets
                if n_tweets < max_tweets
                    cursor = next
                    put!(channel, tweet)
                else
                    break
                end
                n_tweets += 1
            end
        end
    end
end

"""
    fetch_profiles(query::String, max_profiles::Int, cursor::Union{String,Nothing})::FetchProfilesResponse

Type for profile fetch function.
"""
function fetch_profiles(query::String, max_profiles::Int, 
                       cursor::Union{String,Nothing})::FetchProfilesResponse
    # Implementation in concrete scraper classes
    error("fetch_profiles must be implemented in scraper class")
end

"""
    fetch_tweets(query::String, max_tweets::Int, cursor::Union{String,Nothing})::FetchTweetsResponse

Type for tweet fetch function.
"""
function fetch_tweets(query::String, max_tweets::Int, 
                     cursor::Union{String,Nothing})::FetchTweetsResponse
    # Implementation in concrete scraper classes
    error("fetch_tweets must be implemented in scraper class")
end

export get_user_timeline, get_tweet_timeline, fetch_profiles, fetch_tweets

end # module 