module Relationships

using HTTP
using JSON3
using URIs
using ..Types
using ..API
using ..APIv2
using ..Retry

export follow_user, unfollow_user, get_followers, get_following

"""
    follow_user(scraper, user_id)

Follows a user.
"""
function follow_user(scraper::Scraper, user_id)
    response = make_request(
        scraper,
        "POST",
        "https://api.twitter.com/2/users/$(ENV["TWITTER_USER_ID"])/following",
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("target_user_id" => user_id))
    )
    
    return response.status == 200
end

"""
    unfollow_user(scraper, user_id)

Unfollows a user.
"""
function unfollow_user(scraper::Scraper, user_id)
    response = make_request(
        scraper,
        "DELETE",
        "https://api.twitter.com/2/users/$(ENV["TWITTER_USER_ID"])/following/$user_id",
        ["Content-Type" => "application/json"]
    )
    
    return response.status == 200
end

"""
    get_followers(scraper, user_id; max_results=100)

Retrieves the followers of a user.
"""
function get_followers(scraper::Scraper, user_id; max_results=100)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/users/$user_id/followers?max_results=$max_results",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

"""
    get_following(scraper, user_id; max_results=100)

Retrieves the users that a user follows.
"""
function get_following(scraper::Scraper, user_id; max_results=100)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/users/$user_id/following?max_results=$max_results",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

end # module 