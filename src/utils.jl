module Utils

export perform_request

function perform_request(method::String, url::String; headers=Dict(), body=nothing, query=Dict())
    options = HTTP.RequestOptions(
        headers = headers,
        body = body,
        query = query
    )

    response = HTTP.request(method, url, options)
    return response
end

end # module 