module Constants

export API_ENDPOINTS, DEFAULT_HEADERS

# Twitter API endpoint definitions
const API_ENDPOINTS = Dict(
    "USER_TWEETS" => "https://api.twitter.com/2/users/:id/tweets",
    "SEARCH_TWEETS" => "https://api.twitter.com/2/tweets/search/recent",
    # Additional endpoints...
)

# Default HTTP headers for API requests
const DEFAULT_HEADERS = Dict(
    "Content-Type" => "application/json",
    "Accept" => "application/json"
)

end # module 