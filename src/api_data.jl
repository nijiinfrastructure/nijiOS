module APIData

using JSON3
using URIs

# Twitter API Endpoints
const ENDPOINTS = Dict{String,String}(
    "UserTweets" => "https://twitter.com/i/api/graphql/V7H0Ap3_Hh2FyS75OCDO3Q/UserTweets",
    "UserTweetsAndReplies" => "https://twitter.com/i/api/graphql/E4wA5vo2sjVyvpliUffSCw/UserTweetsAndReplies",
    "UserLikedTweets" => "https://twitter.com/i/api/graphql/eSSNbhECHHWWALkkQq-YTA/Likes",
    "TweetDetail" => "https://twitter.com/i/api/graphql/xOhkmRac04YFZmOzU9PJHg/TweetDetail",
    "TweetDetailArticle" => "https://twitter.com/i/api/graphql/GtcBtFhtQymrpxAs5MALVA/TweetDetail",
    "TweetResultByRestId" => "https://twitter.com/i/api/graphql/DJS3BdhUhcaEpZ7B7irJDg/TweetResultByRestId",
    "ListTweets" => "https://twitter.com/i/api/graphql/whF0_KH1fCkdLLoyNPMoEw/ListLatestTweetsTimeline"
)

"""
    EndpointFieldInfo

Contains information about the fields of an API endpoint.

# Fields
- `variables::Dict`: Request variables for arguments like User IDs or Result Counts
- `features::Dict`: Feature flags for the request
- `fieldToggles::Dict`: Optional field toggles for response field display
"""
struct EndpointFieldInfo
    variables::Dict{String,Any}
    features::Dict{String,Any}
    fieldToggles::Union{Dict{String,Any},Nothing}
end

"""
    APIRequest

Wrapper class for API request information.
"""
mutable struct APIRequest
    url::String
    variables::Union{Dict{String,Any},Nothing}
    features::Union{Dict{String,Any},Nothing}
    fieldToggles::Union{Dict{String,Any},Nothing}
end

"""
    APIRequest(info::NamedTuple)

Constructor for APIRequest from a NamedTuple.
"""
function APIRequest(info::NamedTuple)
    APIRequest(
        info.url,
        info.variables,
        info.features,
        info.fieldToggles
    )
end

"""
    to_request_url(request::APIRequest)::String

Converts the request to a complete URL for the Twitter API.
"""
function to_request_url(request::APIRequest)::String
    params = []
    
    if !isnothing(request.variables)
        push!(params, "variables=$(JSON3.write(request.variables))")
    end
    
    if !isnothing(request.features)
        push!(params, "features=$(JSON3.write(request.features))")
    end
    
    if !isnothing(request.fieldToggles)
        push!(params, "fieldToggles=$(JSON3.write(request.fieldToggles))")
    end
    
    query_string = join(params, "&")
    return isempty(query_string) ? request.url : "$(request.url)?$(query_string)"
end

"""
    parse_endpoint_example(example::String)::APIRequest

Analyzes an example URL of a Twitter API endpoint and extracts the GraphQL parameters.
"""
function parse_endpoint_example(example::String)::APIRequest
    uri = URI(example)
    base = "$(uri.scheme)://$(uri.host)$(uri.path)"
    
    params = Dict(pair.first => pair.second for pair in queryparams(uri))
    
    APIRequest((
        url = base,
        variables = haskey(params, "variables") ? JSON3.read(params["variables"]) : nothing,
        features = haskey(params, "features") ? JSON3.read(params["features"]) : nothing,
        fieldToggles = haskey(params, "fieldToggles") ? JSON3.read(params["fieldToggles"]) : nothing
    ))
end

# Factory-Functions for each endpoint
for (name, url) in ENDPOINTS
    @eval begin
        export $(Symbol("create_$(lowercase(name))_request"))
        
        function $(Symbol("create_$(lowercase(name))_request"))()
            parse_endpoint_example($url)
        end
    end
end

end # module 