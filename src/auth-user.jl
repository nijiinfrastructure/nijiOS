struct TwitterUserAuth <: AbstractTwitterAuth
    bearer_token::String
    cookies::Dict{String,String}
    csrf_token::String
    cookie_string::String
    guest_token::Union{String,Nothing}
end

function TwitterUserAuth(bearer_token::String)
    return TwitterUserAuth(
        bearer_token,
        Dict{String,String}(),
        "",
        "",
        nothing
    )
end

"""
    is_logged_in(auth::TwitterUserAuth)

Checks if the current authentication is valid by verifying credentials with Twitter API.
"""
function is_logged_in(auth::TwitterUserAuth)
    url = "https://api.twitter.com/1.1/account/verify_credentials.json"
    
    headers = Dict{String,String}()
    install_to!(auth, headers)
    
    try
        response = HTTP.get(url, headers)
        if response.status != 200
            return false
        end
        
        body = JSON3.read(response.body)
        return !haskey(body, "errors")
    catch e
        @warn "Verify credentials failed" exception=e
        return false
    end
end

"""
    install_to!(auth::TwitterUserAuth, headers::Dict)

Installs authentication headers into the provided headers dictionary.
"""
function install_to!(auth::TwitterUserAuth, headers::Dict)
    headers["authorization"] = "Bearer $(auth.bearer_token)"
    headers["cookie"] = auth.cookie_string
    headers["x-csrf-token"] = auth.csrf_token
    headers["x-twitter-auth-type"] = "OAuth2Client"
    headers["x-twitter-active-user"] = "yes"
    headers["content-type"] = "application/json"
    headers["User-Agent"] = "Mozilla/5.0 (Linux; Android 11; Nokia G20) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.88 Mobile Safari/537.36"
    headers["x-twitter-client-language"] = "en"
    
    if !isnothing(auth.guest_token)
        headers["x-guest-token"] = auth.guest_token
    end
end

"""
    update_guest_token!(auth::TwitterUserAuth)

Updates the guest token by making a request to Twitter's guest token endpoint.
Returns true if successful, false otherwise.
"""
function update_guest_token!(auth::TwitterUserAuth)
    url = "https://api.twitter.com/1.1/guest/activate.json"
    
    headers = Dict{String,String}(
        "authorization" => "Bearer $(auth.bearer_token)"
    )
    
    try
        response = HTTP.post(url, headers)
        if response.status == 200
            body = JSON3.read(response.body)
            auth.guest_token = body.guest_token
            return true
        end
    catch e
        @warn "Failed to update guest token" exception=e
    end
    return false
end

"""
    login!(auth::TwitterUserAuth, username::String, password::String; email::Union{String,Nothing}=nothing)

Performs login flow with Twitter using provided credentials.
Returns true if login successful, false otherwise.
"""
function login!(auth::TwitterUserAuth, username::String, password::String; email::Union{String,Nothing}=nothing)
    url = "https://api.twitter.com/1.1/onboarding/task.json"
    
    # Update guest token first
    if !update_guest_token!(auth)
        @warn "Failed to get guest token"
        return false
    end
    
    # Initial login request
    body = Dict(
        "flow_name" => "login",
        "input_flow_data" => Dict{String,Any}()
    )

    headers = Dict{String,String}()
    install_to!(auth, headers)
    
    try
        response = HTTP.post(url, headers, JSON3.write(body))
        flow_token = JSON3.read(response.body)["flow_token"]
        
        # Send username
        body = Dict(
            "flow_token" => flow_token,
            "subtask_inputs" => [
                Dict(
                    "subtask_id" => "LoginEnterUserIdentifierSSO",
                    "enter_text" => Dict(
                        "text" => username,
                        "link" => "next_link"
                    )
                )
            ]
        )
        
        response = HTTP.post(url, headers, JSON3.write(body))
        flow_token = JSON3.read(response.body)["flow_token"]
        
        # Send password
        body = Dict(
            "flow_token" => flow_token,
            "subtask_inputs" => [
                Dict(
                    "subtask_id" => "LoginEnterPassword",
                    "enter_password" => Dict(
                        "password" => password,
                        "link" => "next_link"
                    )
                )
            ]
        )
        
        response = HTTP.post(url, headers, JSON3.write(body))
        
        # Update cookies and tokens from response
        if haskey(response.headers, "set-cookie")
            for cookie in split(response.headers["set-cookie"], ", ")
                if startswith(cookie, "auth_token=")
                    auth.cookies["auth_token"] = split(split(cookie, "=")[2], ";")[1]
                elseif startswith(cookie, "ct0=")
                    auth.cookies["ct0"] = split(split(cookie, "=")[2], ";")[1]
                    auth.csrf_token = auth.cookies["ct0"]
                end
            end
            auth.cookie_string = join(["$k=$v" for (k,v) in auth.cookies], "; ")
        end
        
        return true
    catch e
        @warn "Login failed" exception=e
        return false
    end
end

"""
    post_tweet(auth::TwitterUserAuth, text::String)

Posts a new tweet using the authenticated user's account.
Returns the API response data if successful, nothing if failed.
"""
function post_tweet(auth::TwitterUserAuth, text::String)
    url = "https://twitter.com/i/api/graphql/YNXM2DGuE2Sff6a2JD3Ztw/CreateTweet"
    
    # Request body based on TS implementation
    body = Dict(
        "variables" => Dict(
            "tweet_text" => text,
            "dark_request" => false,
            "media" => Dict(
                "media_entities" => [],
                "possibly_sensitive" => false
            ),
            "semantic_annotation_ids" => []
        ),
        "features" => Dict(
            "freedom_of_speech_not_reach_fetch_enabled" => true,
            "graphql_is_translatable_rweb_tweet_is_translatable_enabled" => true,
            "longform_notetweets_consumption_enabled" => true,
            "responsive_web_edit_tweet_api_enabled" => true,
            "tweet_awards_web_tipping_enabled" => false,
            "longform_notetweets_rich_text_read_enabled" => true,
            "longform_notetweets_inline_media_enabled" => true,
            "responsive_web_enhance_cards_enabled" => false
        ),
        "queryId" => "YNXM2DGuE2Sff6a2JD3Ztw"
    )

    # Headers based on TS implementation
    headers = Dict{String,String}()
    install_to!(auth, headers)

    try
        response = HTTP.post(url, headers, JSON3.write(body))
        result = JSON3.read(response.body)
        
        # Check for errors in API response
        if haskey(result, "errors")
            error_msg = result.errors[1].message
            error_code = result.errors[1].code
            @warn "Tweet failed" error_msg error_code
            return nothing
        end
        
        return result
    catch e
        @warn "Tweet request failed" exception=e
        return nothing
    end
end 