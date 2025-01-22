using Dates

"""
Rate Limiter for Twitter API Requests
"""
mutable struct RateLimiter
    window_start::DateTime
    request_count::Int
    max_requests::Int
    window_seconds::Int
end

"""
    RateLimiter(max_requests::Int, window_seconds::Int)

Creates a new Rate Limiter.
"""
function RateLimiter(max_requests::Int=180, window_seconds::Int=900)
    RateLimiter(now(), 0, max_requests, window_seconds)
end

"""
    check_rate_limit!(limiter::RateLimiter)

Checks and updates rate limit status.
"""
function check_rate_limit!(limiter::RateLimiter)
    current_time = now()
    window_duration = Millisecond(limiter.window_seconds * 1000)
    
    # Reset if time window has expired
    if current_time - limiter.window_start > window_duration
        limiter.window_start = current_time
        limiter.request_count = 0
    end
    
    # Check limit
    if limiter.request_count >= limiter.max_requests
        wait_time = window_duration - (current_time - limiter.window_start)
        throw(ErrorException("Rate limit exceeded. Wait $(wait_time.value/1000) seconds."))
    end
    
    limiter.request_count += 1
    return true
end 