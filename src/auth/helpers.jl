"""
Install auth headers in a dict
"""
function install_to!(auth::TwitterUserAuth, headers::Dict{String,String})
    headers["Authorization"] = "Bearer $(auth.bearer_token)"
    
    if haskey(auth.cookies, "ct0")
        headers["x-csrf-token"] = auth.cookies["ct0"]
    end
    
    if !isempty(auth.cookies)
        headers["Cookie"] = join(["$k=$v" for (k,v) in auth.cookies], "; ")
    end
    
    headers["x-twitter-auth-type"] = "OAuth2Client"
    headers["x-twitter-active-user"] = "yes"
    headers["x-twitter-client-language"] = "en"
end

"""
check if user is logged in
"""
function is_logged_in(auth::TwitterUserAuth)::Bool
    try
        response = HTTP.get(
            "https://api.twitter.com/1.1/account/verify_credentials.json",
            ["Authorization" => "Bearer $(auth.bearer_token)"]
        )
        return response.status == 200
    catch
        return false
    end
end 