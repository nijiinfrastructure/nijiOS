module ProfileHandler

using HTTP
using JSON3
using URIs
using ..Types
using ..API
using ..APIv2
using ..Retry

export get_profile, update_profile

"""
    get_profile(scraper, username)

Retrieves a user's profile.
"""
function get_profile(scraper::Scraper, username)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/users/by/username/$username",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

"""
    update_profile(scraper, params)

Updates the authenticated user's profile.
"""
function update_profile(scraper::Scraper, params)
    response = make_request(
        scraper,
        "POST",
        "https://api.twitter.com/2/users/me",
        ["Content-Type" => "application/json"],
        JSON3.write(params)
    )
    
    return JSON3.read(response.body)
end

end # module 