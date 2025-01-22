module Trends

using HTTP
using JSON3
using URIs
using ..Types
using ..API
using ..APIv2
using ..Retry

export get_trends, get_trending_topics

"""
    get_trends(scraper; woeid=1)

Gets the current trends for a specific location.
WOEID 1 is worldwide.
"""
function get_trends(scraper::Scraper; woeid=1)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/1.1/trends/place.json?id=$(woeid)",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

"""
    get_trending_topics(scraper)

Gets the current trending topics.
"""
function get_trending_topics(scraper::Scraper)
    response = make_request_v2(
        scraper,
        "GET",
        "https://api.twitter.com/2/trends/available",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

end # module 