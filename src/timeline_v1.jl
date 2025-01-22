module TwitterTimelineV1

using Dates
using ..TwitterTypes
using ..TwitterTimelineTypes
using ..TwitterProfile
using ..TwitterTimelineUtils

"""
    parse_legacy_tweet(user::LegacyUserRaw, tweet::LegacyTweetRaw)::ParseTweetResult

Parses a legacy tweet with its associated user information.
"""
function parse_legacy_tweet(user::LegacyUserRaw, tweet::LegacyTweetRaw)::ParseTweetResult
    # Validate tweet ID
    if isnothing(tweet.id_str)
        return ParseTweetResult(false, "Tweet ID missing")
    end

    # Extract media and entities
    media = get(get(tweet, :extended_entities, Dict()), :media, [])
    media_groups = parse_media_groups(media)
    
    # Create tweet object
    tw = Tweet(
        tweet.id_str,
        get(tweet, :conversation_id_str, tweet.id_str),
        get(tweet, :full_text, ""),
        user.screen_name,
        user.name,
        "https://twitter.com/$(user.screen_name)/status/$(tweet.id_str)",
        DateTime(tweet.created_at),
        get(tweet, :favorite_count, 0),
        get(tweet, :retweet_count, 0),
        get(tweet, :reply_count, 0),
        media_groups.photos,
        media_groups.videos,
        [], # hashtags
        [], # mentions
        [], # urls
        false, # is_quoted
        false, # is_reply
        false, # is_retweet
        false  # is_pin
    )

    # Process hashtags
    hashtags = get(get(tweet, :entities, Dict()), :hashtags, [])
    tw.hashtags = filter(h -> !isnothing(h.text), hashtags) .|> h -> h.text

    # Process mentions
    mentions = get(get(tweet, :entities, Dict()), :user_mentions, [])
    tw.mentions = filter(m -> !isnothing(m.id_str), mentions) .|> m -> UserMention(
        m.id_str,
        m.screen_name,
        m.name
    )

    # Process URLs
    urls = get(get(tweet, :entities, Dict()), :urls, [])
    tw.urls = filter(u -> !isnothing(u.expanded_url), urls) .|> u -> u.expanded_url

    # Quote, Reply and Retweet Status
    if !isnothing(get(tweet, :quoted_status_id_str, nothing))
        tw.is_quoted = true
        tw.quoted_status_id = tweet.quoted_status_id_str
    end

    if !isnothing(get(tweet, :in_reply_to_status_id_str, nothing))
        tw.is_reply = true
        tw.in_reply_to_status_id = tweet.in_reply_to_status_id_str
    end

    if !isnothing(get(tweet, :retweeted_status_id_str, nothing))
        tw.is_retweet = true
        tw.retweeted_status_id = tweet.retweeted_status_id_str
    end

    # Generate HTML
    tw.html = reconstruct_tweet_html(tweet, tw.photos, tw.videos)

    return ParseTweetResult(true, tw)
end

"""
    parse_tweets(timeline::TimelineV1)::QueryTweetsResponse

Parses a Timeline V1 response and extracts the tweets.
"""
function parse_tweets(timeline::TimelineV1)::QueryTweetsResponse
    tweets = Dict{String,Tweet}()
    users = Dict{String,LegacyUserRaw}()
    
    # Process Global Objects
    if !isnothing(timeline.global_objects)
        # Extract tweets
        for (id, tweet) in get(timeline.global_objects, :tweets, Dict())
            if !isnothing(tweet)
                tweets[id] = tweet
            end
        end
        
        # Extract users
        for (id, user) in get(timeline.global_objects, :users, Dict())
            if !isnothing(user)
                users[id] = user
            end
        end
    end

    # Process Timeline Instructions
    ordered_tweets = Tweet[]
    bottom_cursor = nothing
    top_cursor = nothing
    pinned_tweet = nothing

    for instruction in get(timeline.timeline, :instructions, [])
        # Process entries
        for entry in get(get(instruction, :addEntries, Dict()), :entries, [])
            tweet_id = get(get(get(entry, :content, Dict()), :item, Dict()), :id, nothing)
            if !isnothing(tweet_id)
                tweet = get(tweets, tweet_id, nothing)
                user = get(users, get(tweet, :user_id_str, ""), nothing)
                
                if !isnothing(tweet) && !isnothing(user)
                    result = parse_legacy_tweet(user, tweet)
                    if result.success
                        if get(entry, :pinned, false)
                            pinned_tweet = result.tweet
                        else
                            push!(ordered_tweets, result.tweet)
                        end
                    end
                end
            end

            # Process cursor
            cursor = get(get(get(entry, :content, Dict()), :operation, Dict()), :cursor, Dict())
            if get(cursor, :cursorType, nothing) == "Bottom"
                bottom_cursor = get(cursor, :value, nothing)
            elseif get(cursor, :cursorType, nothing) == "Top"
                top_cursor = get(cursor, :value, nothing)
            end
        end
    end

    # Add pinned tweet
    if !isnothing(pinned_tweet) && !isempty(ordered_tweets)
        pushfirst!(ordered_tweets, pinned_tweet)
    end

    return QueryTweetsResponse(ordered_tweets, bottom_cursor, top_cursor)
end

"""
    parse_users(timeline::TimelineV1)::QueryProfilesResponse

Parses a Timeline V1 response and extracts the user profiles.
"""
function parse_users(timeline::TimelineV1)::QueryProfilesResponse
    users = Dict{String,Profile}()
    
    # Process Global Objects
    if !isnothing(timeline.global_objects)
        for (id, legacy) in get(timeline.global_objects, :users, Dict())
            if !isnothing(legacy)
                user = parse_profile(legacy)
                users[id] = user
            end
        end
    end

    # Process Timeline Instructions
    ordered_profiles = Profile[]
    bottom_cursor = nothing
    top_cursor = nothing

    for instruction in get(timeline.timeline, :instructions, [])
        for entry in get(get(instruction, :addEntries, Dict()), :entries, [])
            user_id = get(get(get(get(entry, :content, Dict()), :item, Dict()),
                              :content, Dict()), :user, Dict()).id
            
            profile = get(users, user_id, nothing)
            if !isnothing(profile)
                push!(ordered_profiles, profile)
            end

            # Process cursor
            cursor = get(get(get(entry, :content, Dict()), :operation, Dict()), :cursor, Dict())
            if get(cursor, :cursorType, nothing) == "Bottom"
                bottom_cursor = get(cursor, :value, nothing)
            elseif get(cursor, :cursorType, nothing) == "Top"
                top_cursor = get(cursor, :value, nothing)
            end
        end
    end

    return QueryProfilesResponse(ordered_profiles, bottom_cursor, top_cursor)
end

export parse_legacy_tweet, parse_tweets, parse_users

end # module 