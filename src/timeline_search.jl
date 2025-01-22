module TwitterTimelineSearch

using ..TwitterTypes
using ..TwitterProfile
using ..TwitterTimelineTypes
using ..TwitterTimelineV2

"""
    parse_search_timeline_tweets(timeline::SearchTimeline)::QueryTweetsResponse

Parses tweets from a search timeline.
"""
function parse_search_timeline_tweets(timeline::SearchTimeline)::QueryTweetsResponse
    bottom_cursor = nothing
    top_cursor = nothing
    tweets = Tweet[]
    
    # Extract instructions from timeline
    instructions = get(get(get(get(timeline.data, :search_by_raw_query, Dict()),
                              :search_timeline, Dict()),
                         :timeline, Dict()),
                    :instructions, [])
    
    for instruction in instructions
        if instruction.type == "TimelineAddEntries" || 
           instruction.type == "TimelineReplaceEntry"
            
            # Process entry cursor
            if !isnothing(get(instruction, :entry, nothing))
                entry_content = get(instruction.entry, :content, nothing)
                if !isnothing(entry_content)
                    if get(entry_content, :cursorType, nothing) == "Top"
                        top_cursor = get(entry_content, :value, nothing)
                        continue
                    end
                end
            end

            # Process entries
            entries = get(instruction, :entries, [])
            for entry in entries
                entry_content = get(entry, :content, nothing)
                if isnothing(entry_content)
                    continue
                end

                # Process cursor
                if get(entry_content, :cursorType, nothing) == "Bottom"
                    bottom_cursor = get(entry_content, :value, nothing)
                    continue
                end

                # Validate tweet ID
                id_str = entry.entryId
                if !startswith(id_str, "tweet-") && !startswith(id_str, "search-conversation")
                    continue
                end

                # Process tweet content
                if !isnothing(get(entry_content, :itemContent, nothing))
                    parse_and_push(tweets, entry_content.itemContent, id_str)
                elseif !isnothing(get(entry_content, :items, nothing))
                    for content_item in entry_content.items
                        if !isnothing(get(content_item, :item, nothing)) &&
                           !isnothing(get(content_item.item, :itemContent, nothing)) &&
                           !isnothing(get(content_item, :entryId, nothing))
                            parse_and_push(
                                tweets,
                                content_item.item.itemContent,
                                split(content_item.entryId, "tweet-")[2]
                            )
                        end
                    end
                end
            end
        end
    end
    
    return QueryTweetsResponse(tweets, bottom_cursor, top_cursor)
end

"""
    parse_search_timeline_profiles(timeline::SearchTimeline)::QueryProfilesResponse

Parses profiles from a search timeline.
"""
function parse_search_timeline_profiles(timeline::SearchTimeline)::QueryProfilesResponse
    bottom_cursor = nothing
    top_cursor = nothing
    profiles = Profile[]
    
    # Extract instructions from timeline
    instructions = get(get(get(get(timeline.data, :search_by_raw_query, Dict()),
                              :search_timeline, Dict()),
                         :timeline, Dict()),
                    :instructions, [])
    
    for instruction in instructions
        if instruction.type == "TimelineAddEntries"
            # Process entry cursor
            if !isnothing(get(instruction, :entry, nothing))
                entry_content = get(instruction.entry, :content, nothing)
                if !isnothing(entry_content)
                    if get(entry_content, :cursorType, nothing) == "Top"
                        top_cursor = get(entry_content, :value, nothing)
                        continue
                    end
                end
            end

            # Process entries
            entries = get(instruction, :entries, [])
            for entry in entries
                item_content = get(get(entry, :content, Dict()), :itemContent, nothing)
                if !isnothing(item_content) && get(item_content, :userDisplayType, nothing) == "User"
                    user_result = get(get(item_content, :user_results, Dict()), :result, nothing)
                    
                    if !isnothing(user_result) && !isnothing(get(user_result, :legacy, nothing))
                        profile = parse_profile(
                            user_result.legacy,
                            get(user_result, :is_blue_verified, false)
                        )
                        
                        if isnothing(profile.user_id)
                            profile.user_id = get(user_result, :rest_id, nothing)
                        end
                        
                        push!(profiles, profile)
                    end
                elseif !isnothing(get(get(entry, :content, Dict()), :cursorType, nothing))
                    cursor_type = get(get(entry, :content, Dict()), :cursorType, nothing)
                    if cursor_type == "Bottom"
                        bottom_cursor = get(get(entry, :content, Dict()), :value, nothing)
                    end
                end
            end
        end
    end
    
    return QueryProfilesResponse(profiles, bottom_cursor, top_cursor)
end

"""
    SearchTimeline

Type for the search timeline.
"""
struct SearchTimeline
    data::Union{Nothing,Dict{String,Any}}
end

export parse_search_timeline_tweets, parse_search_timeline_profiles, SearchTimeline

end # module 