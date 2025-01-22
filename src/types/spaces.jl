module TwitterSpacesTypes

"""
    Community

Represents a community that can host Spaces.
"""
struct Community
    id::String
    name::String
    rest_id::String
end

"""
    CommunitySelectQueryResponse

Represents the response structure for the CommunitySelectQuery.
"""
struct CommunitySelectQueryResponse
    data::Dict{Symbol,Vector{Community}}
    errors::Union{Vector{Any},Nothing}
end

"""
    Subtopic

Represents a subtopic within a category.
"""
struct Subtopic
    icon_url::String
    name::String
    topic_id::String
end

"""
    Category

Represents a category that contains multiple subtopics.
"""
struct Category
    icon::String
    name::String
    semantic_core_entity_id::String
    subtopics::Vector{Subtopic}
end

"""
    BrowseSpaceTopics

Represents the data structure for BrowseSpaceTopics.
"""
struct BrowseSpaceTopics
    categories::Vector{Category}
end

"""
    BrowseSpaceTopicsResponse

Represents the response structure for the BrowseSpaceTopics query.
"""
struct BrowseSpaceTopicsResponse
    data::Dict{Symbol,BrowseSpaceTopics}
    errors::Union{Vector{Any},Nothing}
end

"""
    CreatorResult

Represents the result details of a creator.
"""
struct CreatorResult
    typename::String
    id::String
    rest_id::String
    affiliates_highlighted_label::Dict{String,Any}
    has_graduated_access::Bool
    is_blue_verified::Bool
    profile_image_shape::String
    legacy::Dict{String,Any}
    tipjar_settings::Dict{String,Any}
end

"""
    UserResults

Represents user results within an Admin.
"""
struct UserResults
    rest_id::String
    result::Dict{Symbol,Any}
end

"""
    Admin

Represents an admin participant in an Audio Space.
"""
struct Admin
    periscope_user_id::String
    start::Int
    twitter_screen_name::String
    display_name::String
    avatar_url::String
    is_verified::Bool
    is_muted_by_admin::Bool
    is_muted_by_guest::Bool
    user_results::UserResults
end

"""
    Participants

Represents participants in an Audio Space.
"""
struct Participants
    total::Int
    admins::Vector{Admin}
    speakers::Vector{Any}
    listeners::Vector{Any}
end

"""
    Metadata

Represents metadata of an Audio Space.
"""
struct Metadata
    rest_id::String
    state::String
    media_key::String
    created_at::Int
    started_at::Int
    ended_at::String
    updated_at::Int
    content_type::String
    creator_results::Dict{Symbol,CreatorResult}
    conversation_controls::Int
    disallow_join::Bool
    is_employee_only::Bool
    is_locked::Bool
    is_muted::Bool
    is_space_available_for_clipping::Bool
    is_space_available_for_replay::Bool
    narrow_cast_space_type::Int
    no_incognito::Bool
    total_replay_watched::Int
    total_live_listeners::Int
    tweet_results::Dict{String,Any}
    max_guest_sessions::Int
    max_admin_capacity::Int
end

"""
    Sharings

Represents shares within an Audio Space.
"""
struct Sharings
    items::Vector{Any}
    slice_info::Dict{String,Any}
end

"""
    AudioSpace

Represents an Audio Space.
"""
struct AudioSpace
    metadata::Metadata
    is_subscribed::Bool
    participants::Participants
    sharings::Sharings
end

"""
    AudioSpaceByIdResponse

Represents the response structure for the AudioSpaceById query.
"""
struct AudioSpaceByIdResponse
    data::Dict{Symbol,AudioSpace}
    errors::Union{Vector{Any},Nothing}
end

"""
    AudioSpaceByIdVariables

Represents the required variables for the AudioSpaceById query.
"""
struct AudioSpaceByIdVariables
    id::String
    is_metatags_query::Bool
    with_replays::Bool
    with_listeners::Bool
end

"""
    LiveVideoSource

Represents the source of a live video.
"""
struct LiveVideoSource
    location::String
    no_redirect_playback_url::String
    status::String
    stream_type::String
end

"""
    LiveVideoStreamStatus

Represents the status of a live video stream.
"""
struct LiveVideoStreamStatus
    source::LiveVideoSource
    session_id::String
    chat_token::String
    lifecycle_token::String
    share_url::String
    chat_permission_type::String
end

"""
    AuthenticatePeriscopeResponse

Represents the response of the Periscope authentication.
"""
struct AuthenticatePeriscopeResponse
    data::Dict{Symbol,String}
    errors::Union{Vector{Any},Nothing}
end

"""
    LoginTwitterTokenResponse

Represents the response of the Twitter login token.
"""
struct LoginTwitterTokenResponse
    cookie::String
    user::Dict{String,Any}
    type::String
end

# Export all types
export Community, CommunitySelectQueryResponse, Subtopic, Category,
       BrowseSpaceTopics, BrowseSpaceTopicsResponse, CreatorResult,
       UserResults, Admin, Participants, Metadata, Sharings,
       AudioSpace, AudioSpaceByIdResponse, AudioSpaceByIdVariables,
       LiveVideoSource, LiveVideoStreamStatus, AuthenticatePeriscopeResponse,
       LoginTwitterTokenResponse

end # module 