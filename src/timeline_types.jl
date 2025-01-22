module TwitterTimelineTypes

# Basic data structures
struct Hashtag
    text::Union{String,Nothing}
end

struct TimelineUserMentionBasic
    id_str::Union{String,Nothing}
    name::Union{String,Nothing}
    screen_name::Union{String,Nothing}
end

struct TimelineMediaBasic
    media_url_https::Union{String,Nothing}
    type::Union{String,Nothing}
    url::Union{String,Nothing}
end

struct TimelineUrlBasic
    expanded_url::Union{String,Nothing}
    url::Union{String,Nothing}
end

struct ExtSensitiveMediaWarning
    adult_content::Bool
    graphic_violence::Bool
    other::Bool
end

struct VideoVariant
    bitrate::Union{Int,Nothing}
    url::Union{String,Nothing}
end

struct VideoInfo
    variants::Vector{VideoVariant}
end

struct TimelineMediaExtended
    id_str::Union{String,Nothing}
    media_url_https::Union{String,Nothing}
    ext_sensitive_media_warning::Union{ExtSensitiveMediaWarning,Nothing}
    type::Union{String,Nothing}
    url::Union{String,Nothing}
    video_info::Union{VideoInfo,Nothing}
    ext_alt_text::Union{String,Nothing}
end

# Response Types
struct QueryTweetsResponse
    tweets::Vector{Tweet}
    next::Union{String,Nothing}
    previous::Union{String,Nothing}
end

struct QueryProfilesResponse
    profiles::Vector{Profile}
    next::Union{String,Nothing}
    previous::Union{String,Nothing}
end

struct FetchProfilesResponse
    profiles::Vector{Profile}
    next::Union{String,Nothing}
end

struct FetchTweetsResponse
    tweets::Vector{Tweet}
    next::Union{String,Nothing}
end

# Timeline specific types
struct TimelineInstruction
    entries::Union{Vector{TimelineEntryRaw},Nothing}
    entry::Union{TimelineEntryRaw,Nothing}
    type::Union{String,Nothing}
end

struct TimelineV1
    global_objects::Union{TimelineGlobalObjectsRaw,Nothing}
    timeline::Union{TimelineDataRaw,Nothing}
end

struct TimelineV2
    data::Union{Dict{String,Any},Nothing}
end

export Hashtag, TimelineUserMentionBasic, TimelineMediaBasic, TimelineUrlBasic,
       ExtSensitiveMediaWarning, VideoVariant, VideoInfo, TimelineMediaExtended,
       QueryTweetsResponse, QueryProfilesResponse, FetchProfilesResponse,
       FetchTweetsResponse, TimelineInstruction, TimelineV1, TimelineV2

end # module 