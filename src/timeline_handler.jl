module TimelineHandler

using HTTP
using JSON3
using URIs
using ..Types
using ..API
using ..APIv2
using ..Retry
using ..TweetTypes

export get_user_timeline, get_home_timeline

"""
    get_user_timeline(scraper, user_id; max_results=100)

Retrieves the timeline of a user.
"""
function get_user_timeline(scraper::Scraper, user_id; max_results=100)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/users/$user_id/tweets?max_results=$max_results",
        ["Content-Type" => "application/json"]
    )
    
    data = JSON3.read(response.body)
    return [Tweet(tweet_data) for tweet_data in data.data]
end

"""
    get_home_timeline(scraper; max_results=100)

Retrieves the home timeline.
"""
function get_home_timeline(scraper::Scraper; max_results=100)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/users/me/home?max_results=$max_results",
        ["Content-Type" => "application/json"]
    )
    
    data = JSON3.read(response.body)
    return [Tweet(tweet_data) for tweet_data in data.data]
end

end # module 