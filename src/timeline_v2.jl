module TwitterTimelineV2

using ..TwitterTypes
using ..TwitterTimelineTypes
using ..TwitterTimelineUtils

"""
    parse_legacy_tweet(user::Union{LegacyUserRaw,Nothing}, tweet::Union{LegacyTweetRaw,Nothing})

Parses a legacy tweet with user information.
"""
function parse_legacy_tweet(user::Union{LegacyUserRaw,Nothing}, 
                          tweet::Union{LegacyTweetRaw,Nothing})::ParseTweetResult
    if isnothing(tweet)
        return ParseTweetResult(false, "Tweet was not found in the timeline object.")
    end

    if isnothing(user)
        return ParseTweetResult(false, "User was not found in the timeline object.")
    end

    # Validate and set tweet ID
    if isnothing(tweet.id_str)
        if isnothing(tweet.conversation_id_str)
            return ParseTweetResult(false, "Tweet ID was not found in object.")
        end
        tweet.id_str = tweet.conversation_id_str
    end

    # Extract entities
    hashtags = get(get(tweet, :entities, Dict()), :hashtags, [])
    mentions = get(get(tweet, :entities, Dict()), :user_mentions, [])
    media = get(get(tweet, :extended_entities, Dict()), :media, [])
    pinned_tweets = Set(get(user, :pinned_tweet_ids_str, []))
    urls = get(get(tweet, :entities, Dict()), :urls, [])
    
    # Parse media
    media_groups = parse_media_groups(media)
    
    # Create tweet object
    tw = Tweet(
        get(tweet, :bookmark_count, nothing),
        tweet.conversation_id_str,
        tweet.id_str,
        filter(h -> !isnothing(h.text), hashtags) .|> h -> h.text,
        get(tweet, :favorite_count, 0),
        filter(m -> !isnothing(m.id_str), mentions) .|> m -> UserMention(
            m.id_str, m.screen_name, m.name
        ),
        user.name,
        "https://twitter.com/$(user.screen_name)/status/$(tweet.id_str)",
        media_groups.photos,
        get(tweet, :reply_count, 0),
        get(tweet, :retweet_count, 0),
        get(tweet, :full_text, ""),
        Tweet[], # thread
        filter(u -> !isnothing(u.expanded_url), urls) .|> u -> u.expanded_url,
        tweet.user_id_str,
        user.screen_name,
        media_groups.videos,
        false, # isQuoted
        false, # isReply
        false, # isRetweet
        false, # isPin
        false  # sensitiveContent
    )

    # Process timestamp
    if !isnothing(tweet.created_at)
        tw.time_parsed = DateTime(tweet.created_at)
        tw.timestamp = floor(Int, datetime2unix(tw.time_parsed))
    end

    # Process place
    if !isnothing(get(tweet, :place, nothing)) && !isnothing(tweet.place.id)
        tw.place = tweet.place
    end

    # Quote, Reply and Retweet Status
    quoted_status_id_str = get(tweet, :quoted_status_id_str, nothing)
    in_reply_to_status_id_str = get(tweet, :in_reply_to_status_id_str, nothing)
    retweeted_status_id_str = get(tweet, :retweeted_status_id_str, nothing)
    retweeted_status_result = get(get(tweet, :retweeted_status_result, Dict()), :result, nothing)

    if !isnothing(quoted_status_id_str)
        tw.is_quoted = true
        tw.quoted_status_id = quoted_status_id_str
    end

    if !isnothing(in_reply_to_status_id_str)
        tw.is_reply = true
        tw.in_reply_to_status_id = in_reply_to_status_id_str
    end

    if !isnothing(retweeted_status_id_str) || !isnothing(retweeted_status_result)
        tw.is_retweet = true
        tw.retweeted_status_id = retweeted_status_id_str

        if !isnothing(retweeted_status_result)
            retweeted_user = get(get(get(get(retweeted_status_result, :core, Dict()),
                                      :user_results, Dict()), :result, Dict()), :legacy, nothing)
            retweeted_tweet = get(retweeted_status_result, :legacy, nothing)
            
            parsed_result = parse_legacy_tweet(retweeted_user, retweeted_tweet)
            if parsed_result.success
                tw.retweeted_status = parsed_result.tweet
            end
        end
    end

    # Process views
    views_count = get(get(tweet, :ext_views, Dict()), :count, nothing)
    if !isnothing(views_count)
        views = tryparse(Int, views_count)
        if !isnothing(views)
            tw.views = views
        end
    end

    # Pin and Sensitive Content Status
    if tweet.id_str in pinned_tweets
        tw.is_pin = true
    end

    if media_groups.sensitive_content
        tw.sensitive_content = true
    end

    # Generate HTML
    tw.html = reconstruct_tweet_html(tweet, tw.photos, tw.videos)

    return ParseTweetResult(true, tw)
end

"""
    parse_result(result::TimelineResultRaw)::ParseTweetResult

Parses a TimelineResultRaw object into a Tweet.
"""
function parse_result(result::TimelineResultRaw)::ParseTweetResult
    if isnothing(result)
        return ParseTweetResult(false, "Timeline result was empty")
    end

    # Extract legacy tweet and user
    legacy_tweet = get(result, :legacy, nothing)
    user_results = get(get(get(result, :core, Dict()), :user_results, Dict()), :result, nothing)
    legacy_user = get(user_results, :legacy, nothing)
    
    if isnothing(legacy_tweet) || isnothing(legacy_user)
        return ParseTweetResult(false, "Missing legacy tweet or user data")
    end

    # Parse tweet
    tweet_result = parse_legacy_tweet(legacy_user, legacy_tweet)
    if !tweet_result.success
        return tweet_result
    end

    # Add views if available
    views_str = get(get(result, :views, Dict()), :count, nothing)
    if !isnothing(views_str)
        views = tryparse(Int, views_str)
        if !isnothing(views)
            tweet_result.tweet.views = views
        end
    end

    # Process quoted tweet
    quoted_result = get(get(result, :quoted_status_result, Dict()), :result, nothing)
    if !isnothing(quoted_result)
        quoted_tweet_result = parse_result(quoted_result)
        if quoted_tweet_result.success
            tweet_result.tweet.quoted_status = quoted_tweet_result.tweet
        end
    end

    return tweet_result
end

"""
    parse_timeline_entry_item_content_raw(content::TimelineEntryItemContentRaw, 
                                        entry_id::String)::ParseTweetResult

Parses a Timeline Entry Item Content object.
"""
function parse_timeline_entry_item_content_raw(content::TimelineEntryItemContentRaw, 
                                             entry_id::String)::ParseTweetResult
    if content.tweetDisplayType == "Tweet"
        result = get(get(content, :tweet_results, Dict()), :result, nothing)
        if !isnothing(result)
            return parse_result(result)
        end
    end
    
    return ParseTweetResult(false, "No valid tweet content found")
end

"""
    parse_and_push(tweets::Vector{Tweet}, content::TimelineEntryItemContentRaw, 
                  entry_id::String, is_conversation::Bool=false)

Parses a Timeline Entry Item and adds the tweet to the list.
"""
function parse_and_push(tweets::Vector{Tweet}, content::TimelineEntryItemContentRaw, 
                       entry_id::String, is_conversation::Bool=false)
    result = parse_timeline_entry_item_content_raw(content, entry_id)
    if result.success
        push!(tweets, result.tweet)
        
        # Process conversation thread
        if is_conversation
            result.tweet.is_self_thread = true
            result.tweet.thread = Tweet[]
        end
    end
end

"""
    parse_threaded_conversation(conversation::ThreadedConversation)::Vector{Tweet}

Parses a nested conversation.
"""
function parse_threaded_conversation(conversation::ThreadedConversation)::Vector{Tweet}
    tweets = Tweet[]
    instructions = get(get(get(conversation.data, :threaded_conversation_with_injections_v2, Dict()),
                         :instructions, []), [])

    for instruction in instructions
        entries = get(instruction, :entries, [])
        for entry in entries
            entry_content = get(get(entry, :content, Dict()), :itemContent, nothing)
            if !isnothing(entry_content)
                parse_and_push(tweets, entry_content, entry.entryId, true)
            end

            for item in get(get(entry, :content, Dict()), :items, [])
                item_content = get(get(get(item, :item, Dict()), :itemContent, nothing))
                if !isnothing(item_content)
                    parse_and_push(tweets, item_content, entry.entryId, true)
                end
            end
        end
    end

    # Build thread relationships
    for tweet in tweets
        # Reply relationships
        if !isnothing(tweet.in_reply_to_status_id)
            for parent_tweet in tweets
                if parent_tweet.id == tweet.in_reply_to_status_id
                    tweet.in_reply_to_status = parent_tweet
                    break
                end
            end
        end

        # Thread relationships
        if tweet.is_self_thread && tweet.conversation_id == tweet.id
            for child_tweet in tweets
                if child_tweet.is_self_thread && child_tweet.id != tweet.id
                    push!(tweet.thread, child_tweet)
                end
            end

            if isempty(tweet.thread)
                tweet.is_self_thread = false
            end
        end
    end

    return tweets
end

"""
    parse_article(conversation::ThreadedConversation)::Vector{TimelineArticle}

Parses articles from a timeline conversation.
"""
function parse_article(conversation::ThreadedConversation)::Vector{TimelineArticle}
    articles = TimelineArticle[]
    instructions = get(get(get(conversation.data, :threaded_conversation_with_injections_v2, Dict()),
                         :instructions, []), [])

    for instruction in instructions
        for entry in get(instruction, :entries, [])
            id = get(get(get(get(get(entry, :content, Dict()), :itemContent, Dict()),
                              :tweet_results, Dict()), :result, Dict()), :rest_id, nothing)
            
            article = get(get(get(get(get(get(entry, :content, Dict()), :itemContent, Dict()),
                                    :tweet_results, Dict()), :result, Dict()), :article, Dict()),
                         :article_results, Dict()).result
            
            if isnothing(id) || isnothing(article)
                continue
            end

            text = join(map(block -> get(block, :text, ""),
                          get(get(article, :content_state, Dict()), :blocks, [])), "\n\n")

            push!(articles, TimelineArticle(
                id,
                get(article, :rest_id, ""),
                get(article, :title, ""),
                get(article, :preview_text, ""),
                get(get(get(get(article, :cover_media, Dict()), :media_info, Dict()),
                       :original_img_url, nothing)),
                text
            ))
        end
    end

    return articles
end

export parse_legacy_tweet, parse_result, parse_timeline_entry_item_content_raw, parse_and_push,
       parse_threaded_conversation, parse_article

end # module 