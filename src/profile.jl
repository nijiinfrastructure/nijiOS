module TwitterProfile

using HTTP
using JSON3
using ..TwitterTypes
using ..TwitterAPI
using ..TwitterAuth

"""
    Profile

Represents a Twitter profile.
"""
struct Profile
    avatar::Union{String,Nothing}
    banner::Union{String,Nothing}
    biography::Union{String,Nothing}
    birthday::Union{String,Nothing}
    followers_count::Union{Int,Nothing}
    following_count::Union{Int,Nothing}
    friends_count::Union{Int,Nothing}
    media_count::Union{Int,Nothing}
    statuses_count::Union{Int,Nothing}
    is_private::Bool
    is_verified::Bool
    is_blue_verified::Bool
    joined::Union{DateTime,Nothing}
    likes_count::Union{Int,Nothing}
    listed_count::Union{Int,Nothing}
    location::String
    name::Union{String,Nothing}
    pinned_tweet_ids::Vector{String}
    tweets_count::Union{Int,Nothing}
    url::Union{String,Nothing}
    user_id::Union{String,Nothing}
    username::Union{String,Nothing}
    website::Union{String,Nothing}
    can_dm::Bool
end

# Cache for User IDs
const ID_CACHE = Dict{String,String}()

"""
    get_avatar_original_size_url(avatar_url::Union{String,Nothing})::Union{String,Nothing}

Converts avatar URL to original size version.
"""
function get_avatar_original_size_url(avatar_url::Union{String,Nothing})::Union{String,Nothing}
    isnothing(avatar_url) ? nothing : replace(avatar_url, "_normal" => "")
end

"""
    parse_profile(user::Dict, is_blue_verified::Bool=false)::Profile

Parses a profile from Twitter API data.
"""
function parse_profile(user::Dict, is_blue_verified::Bool=false)::Profile
    profile = Profile(
        get_avatar_original_size_url(get(user, "profile_image_url_https", nothing)),
        get(user, "profile_banner_url", nothing),
        get(user, "description", nothing),
        nothing, # birthday not in API
        get(user, "followers_count", nothing),
        get(user, "friends_count", nothing),
        get(user, "friends_count", nothing),
        get(user, "media_count", nothing),
        get(user, "statuses_count", nothing),
        get(user, "protected", false),
        get(user, "verified", false),
        is_blue_verified,
        nothing, # joined will be set later
        get(user, "favourites_count", nothing),
        get(user, "listed_count", nothing),
        get(user, "location", ""),
        get(user, "name", nothing),
        get(user, "pinned_tweet_ids_str", String[]),
        get(user, "statuses_count", nothing),
        "https://twitter.com/$(get(user, "screen_name", ""))",
        get(user, "id_str", nothing),
        get(user, "screen_name", nothing),
        nothing, # website will be set later
        get(user, "can_dm", false)
    )

    # Parse created_at date
    created_at = get(user, "created_at", nothing)
    if !isnothing(created_at)
        profile.joined = DateTime(created_at, "E MMM dd HH:mm:ss zzzz yyyy")
    end

    # Extract website from entities
    urls = get(get(get(user, "entities", Dict()), "url", Dict()), "urls", [])
    if !isempty(urls)
        profile.website = get(first(urls), "expanded_url", nothing)
    end

    return profile
end

"""
    get_profile(username::String, auth::TwitterAuth)::Union{Profile,Nothing}

Retrieves a profile by username.
"""
function get_profile(username::String, auth::TwitterAuth)::Union{Profile,Nothing}
    # GraphQL parameters
    variables = Dict(
        "screen_name" => username,
        "withSafetyModeUserFields" => true
    )

    features = Dict(
        "hidden_profile_likes_enabled" => false,
        "hidden_profile_subscriptions_enabled" => false,
        "responsive_web_graphql_exclude_directive_enabled" => true,
        "verified_phone_label_enabled" => false,
        "highlights_tweets_tab_ui_enabled" => true,
        "creator_subscriptions_tweet_preview_api_enabled" => true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled" => false,
        "responsive_web_graphql_timeline_navigation_enabled" => true
    )

    response = make_request(
        auth,
        "GET",
        "https://twitter.com/i/api/graphql/G3KGOASz96M-Qu0nwmGXNg/UserByScreenName",
        query=Dict(
            "variables" => JSON3.write(variables),
            "features" => JSON3.write(features)
        )
    )

    if !response.success
        return nothing
    end

    data = response.data
    user_result = get(get(get(data, "data", Dict()), "user", Dict()), "result", nothing)
    
    if isnothing(user_result)
        return nothing
    end

    legacy = get(user_result, "legacy", Dict())
    is_blue_verified = get(user_result, "is_blue_verified", false)
    
    return parse_profile(legacy, is_blue_verified)
end

"""
    get_screen_name_by_user_id(user_id::String, auth::TwitterAuth)::Union{String,Nothing}

Retrieves the screen name by user ID.
"""
function get_screen_name_by_user_id(user_id::String, auth::TwitterAuth)::Union{String,Nothing}
    variables = Dict(
        "userId" => user_id,
        "withSafetyModeUserFields" => true
    )

    features = Dict(
        "hidden_profile_subscriptions_enabled" => true,
        "responsive_web_graphql_exclude_directive_enabled" => true,
        "verified_phone_label_enabled" => false,
        "highlights_tweets_tab_ui_enabled" => true,
        "creator_subscriptions_tweet_preview_api_enabled" => true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled" => false,
        "responsive_web_graphql_timeline_navigation_enabled" => true
    )

    response = make_request(
        auth,
        "GET",
        "https://twitter.com/i/api/graphql/xf3jd90KKBCUxdlI_tNHZw/UserByRestId",
        query=Dict(
            "variables" => JSON3.write(variables),
            "features" => JSON3.write(features)
        )
    )

    if !response.success
        return nothing
    end

    legacy = get(get(get(get(response.data, "data", Dict()), 
                       "user", Dict()), 
                   "result", Dict()), 
               "legacy", Dict())

    return get(legacy, "screen_name", nothing)
end

"""
    get_user_id_by_screen_name(screen_name::String, auth::TwitterAuth)::Union{String,Nothing}

Retrieves the user ID by screen name.
"""
function get_user_id_by_screen_name(screen_name::String, auth::TwitterAuth)::Union{String,Nothing}
    # Check cache
    cached = get(ID_CACHE, screen_name, nothing)
    if !isnothing(cached)
        return cached
    end

    # Retrieve profile
    profile = get_profile(screen_name, auth)
    if isnothing(profile)
        return nothing
    end

    # Cache and return ID
    if !isnothing(profile.user_id)
        ID_CACHE[screen_name] = profile.user_id
        return profile.user_id
    end

    return nothing
end

export Profile, get_profile, get_screen_name_by_user_id, get_user_id_by_screen_name,
       parse_profile, get_avatar_original_size_url

end # module 