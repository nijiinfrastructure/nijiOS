"""
Flow Token Response Type
"""
struct FlowTokenResponse
    status::String
    subtask::Union{Dict{String,Any},Nothing}
    flow_token::Union{String,Nothing}
end

"""
make a flow task
"""
function execute_flow_task(auth::TwitterUserAuth, data::Dict{String,Any})::FlowTokenResponse
    url = "https://api.twitter.com/1.1/onboarding/task.json"
    
    headers = Dict{String,String}(
        "Content-Type" => "application/json",
        "User-Agent" => "Mozilla/5.0 (Linux; Android 11; Nokia G20) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.88 Mobile Safari/537.36",
        "x-twitter-auth-type" => "OAuth2Client",
        "x-twitter-active-user" => "yes",
        "x-twitter-client-language" => "en"
    )
    
    if !isnothing(auth.guest_token)
        headers["x-guest-token"] = auth.guest_token
    end
    
    install_to!(auth, headers)
    
    response = HTTP.post(url, headers, JSON3.write(data))
    
    result = JSON3.read(response.body)
    
    return FlowTokenResponse(
        get(result, "status", "unknown"),
        get(result, "subtask", nothing),
        get(result, "flow_token", nothing)
    )
end 