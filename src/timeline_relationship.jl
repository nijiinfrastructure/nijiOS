module TwitterTimelineRelationship

using ..TwitterTypes
using ..TwitterProfile
using ..TwitterTimelineTypes
using ..TwitterTimelineV2

"""
    parse_relationship_timeline(timeline::RelationshipTimeline)::QueryProfilesResponse

Parses profiles from a relationship timeline.
"""
function parse_relationship_timeline(timeline::RelationshipTimeline)::QueryProfilesResponse
    bottom_cursor = nothing
    top_cursor = nothing
    profiles = Profile[]
    
    # Extract instructions from timeline
    instructions = get(get(get(get(get(timeline.data, :user, Dict()),
                                  :result, Dict()),
                             :timeline, Dict()),
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
                    elseif cursor_type == "Top"
                        top_cursor = get(get(entry, :content, Dict()), :value, nothing)
                    end
                end
            end
        end
    end
    
    return QueryProfilesResponse(profiles, bottom_cursor, top_cursor)
end

"""
    RelationshipEntryItemContent

Type for the content of a relationship timeline entry.
"""
struct RelationshipEntryItemContent
    itemType::Union{String,Nothing}
    userDisplayType::Union{String,Nothing}
    user_results::Union{Nothing,Dict{String,Any}}
end

"""
    RelationshipEntry

Type for an entry in the relationship timeline.
"""
struct RelationshipEntry
    entryId::String
    sortIndex::String
    content::Union{Nothing,Dict{String,Any}}
end

"""
    RelationshipTimeline

Type for the relationship timeline.
"""
struct RelationshipTimeline
    data::Union{Nothing,Dict{String,Any}}
end

export parse_relationship_timeline, RelationshipEntryItemContent,
       RelationshipEntry, RelationshipTimeline

end # module 