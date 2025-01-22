module SearchHandler

using HTTP
using JSON3
using URIs
using ..Types
using ..API
using ..APIv2
using ..Retry

export search_tweets, search_users

"""
    search_tweets(scraper, query; max_results=100)

Searches for tweets matching the given query.
"""
function search_tweets(scraper::Scraper, query; max_results=100)
    encoded_query = URIs.escapeuri(query)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/tweets/search/recent?query=$(encoded_query)&max_results=$(max_results)",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

"""
    search_users(scraper, query; max_results=100)

Searches for users matching the given query.
"""
function search_users(scraper::Scraper, query; max_results=100)
    encoded_query = URIs.escapeuri(query)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/users/search?q=$(encoded_query)&max_results=$(max_results)",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

end # module 