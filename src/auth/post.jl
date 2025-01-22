"""
Send post
"""
function post_tweet(auth::TwitterUserAuth, text::String; media_ids::Vector{String}=String[])
    url = "https://api.twitter.com/2/tweets"
    
    headers = Dict{String,String}(
        "Content-Type" => "application/json",
        "X-Client-UUID" => string(uuid4()),
        "Cache-Control" => "no-cache"
    )
    
    install_to!(auth, headers)
    
    body = Dict{String,Any}(
        "text" => text
    )
    
    if !isempty(media_ids)
        body["media"] = Dict(
            "media_ids" => media_ids
        )
    end
    
    @info "Sending tweet" url headers body
    
    response = HTTP.post(url, headers, JSON3.write(body))
    
    @info "Raw API Response" String(response.body)
    
    return JSON3.read(response.body)
end

"""
Get tweet by id
"""
function get_tweet(auth::TwitterUserAuth, tweet_id::String)
    url = "https://api.twitter.com/2/tweets/$tweet_id"
    
    headers = Dict{String,String}(
        "Content-Type" => "application/json",
        "Cache-Control" => "no-cache"
    )
    
    install_to!(auth, headers)
    
    @info "Fetching tweet" url headers
    
    response = HTTP.get(url, headers)
    
    @info "Raw API Response" String(response.body)
    
    return JSON3.read(response.body)
end

"""
generate tweet url
"""
function get_tweet_url(tweet_id::String)
    return "https://twitter.com/$(auth.username)/status/$tweet_id"
end 