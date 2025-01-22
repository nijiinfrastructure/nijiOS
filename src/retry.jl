module Retry

export retry_with_backoff

"""
    retry_with_backoff(f::Function; 
                      max_retries::Int=3, 
                      initial_delay::Float64=1.0,
                      max_delay::Float64=60.0,
                      factor::Float64=2.0)

Executes a function with exponential backoff between attempts.

Parameters:
- `f`: The function to execute
- `max_retries`: Maximum number of retry attempts
- `initial_delay`: Initial delay in seconds
- `max_delay`: Maximum delay in seconds
- `factor`: Multiplier for delay
"""
function retry_with_backoff(f::Function; 
                          max_retries::Int=3, 
                          initial_delay::Float64=1.0,
                          max_delay::Float64=60.0,
                          factor::Float64=2.0)
    delay = initial_delay
    last_error = nothing
    
    for attempt in 1:max_retries
        try
            return f()
        catch e
            last_error = e
            if attempt == max_retries
                @error "Maximum number of retries reached" exception=(last_error, catch_backtrace())
                rethrow(last_error)
            end
            
            # Exponential backoff with jitter
            delay = min(delay * factor * (1.0 + 0.2 * rand()), max_delay)
            @warn "Attempt $attempt failed, waiting $(round(delay, digits=2)) seconds" exception=e
            sleep(delay)
        end
    end
    
    error("Unexpected error in retry_with_backoff")
end

end # module 