"""
    check_rate_limit!(scraper::Scraper, endpoint::String)

Checks the rate limit for an endpoint and waits if necessary.
Throws TwitterRateLimitError if the limit is reached.
"""
function check_rate_limit!(scraper::Scraper, endpoint::String)
    if haskey(scraper.rate_limiter.endpoints, endpoint)
        rate_limit = scraper.rate_limiter.endpoints[endpoint]
        
        if rate_limit.remaining <= 0
            wait_time = Dates.value(rate_limit.reset_at - now()) / 1000
            if wait_time > 0
                if wait_time > 300  # 5 minutes
                    throw(TwitterRateLimitError(
                        rate_limit.reset_at,
                        "Rate limit exceeded. Reset in $(round(wait_time/60, digits=1)) minutes"
                    ))
                end
                sleep(wait_time)
            end
        end
    end
end

"""
    update_rate_limit!(scraper::Scraper, endpoint::String, headers::Dict)

Updates rate limit information based on API response headers.
"""
function update_rate_limit!(scraper::Scraper, endpoint::String, headers::Dict{String,String})
    if haskey(headers, "x-rate-limit-remaining") && haskey(headers, "x-rate-limit-reset")
        remaining = parse(Int, headers["x-rate-limit-remaining"])
        reset_unix = parse(Int, headers["x-rate-limit-reset"])
        reset_at = unix2datetime(reset_unix)

        scraper.rate_limiter.endpoints[endpoint] = RateLimitInfo(remaining, reset_at)
    end
end

module TwitterRateLimiter

using Dates
using HTTP
using ..Types

export check_rate_limit, update_rate_limit

"""
    check_rate_limit(limiter::RateLimiter, endpoint::String)

Checks if an endpoint is rate-limited.
"""
function check_rate_limit(limiter::RateLimiter, endpoint::String)
    if haskey(limiter.endpoints, endpoint)
        remaining, reset_time = limiter.endpoints[endpoint]
        if remaining <= 0 && now() < reset_time
            sleep_time = max(0, Dates.value(reset_time - now()) / 1000)
            sleep(sleep_time)
        end
    end
end

"""
    update_rate_limit(limiter::RateLimiter, endpoint::String, response::HTTP.Response)

Updates rate limit information from an HTTP response.
"""
function update_rate_limit(limiter::RateLimiter, endpoint::String, response::HTTP.Response)
    if haskey(response.headers, "x-rate-limit-remaining") && 
       haskey(response.headers, "x-rate-limit-reset")
        remaining = parse(Int, response.headers["x-rate-limit-remaining"])
        reset_time = DateTime(parse(Int, response.headers["x-rate-limit-reset"]))
        limiter.endpoints[endpoint] = (remaining, reset_time)
    end
end

end # module 