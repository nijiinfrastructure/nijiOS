using HTTP
using JSON

"""
Base error type for Twitter API errors
"""
abstract type TwitterError <: Exception end

"""
Authentication error
"""
struct AuthenticationError <: TwitterError
    message::String
    status_code::Union{Int,Nothing}
    response::Union{HTTP.Response,Nothing}
end

"""
Rate limiting error
"""
struct RateLimitError <: TwitterError
    message::String
    reset_time::Union{DateTime,Nothing}
    limit::Int
    remaining::Int
end

"""
API request error
"""
struct APIError <: TwitterError
    message::String
    status_code::Int
    errors::Vector{Dict{String,Any}}
    response::HTTP.Response
end

"""
Parameter validation error
"""
struct ValidationError <: TwitterError
    message::String
    field::String
    details::Dict{String,Any}
end

"""
Network-related error
"""
struct NetworkError <: TwitterError
    message::String
    original_error::Exception
end

"""
    parse_twitter_error(response::HTTP.Response)

Parses Twitter API error messages and creates corresponding error objects.
"""
function parse_twitter_error(response::HTTP.Response)
    try
        error_data = JSON.parse(String(response.body))
        
        # Rate Limit Check
        if response.status == 429
            reset_time = haskey(response.headers, "x-rate-limit-reset") ?
                unix2datetime(parse(Int, response.headers["x-rate-limit-reset"])) :
                nothing
                
            limit = parse(Int, get(response.headers, "x-rate-limit-limit", "-1"))
            remaining = parse(Int, get(response.headers, "x-rate-limit-remaining", "0"))
            
            return RateLimitError(
                "Rate limit exceeded",
                reset_time,
                limit,
                remaining
            )
        end
        
        # Authentication Error
        if response.status in [401, 403]
            return AuthenticationError(
                get(error_data, "message", "Authentication failed"),
                response.status,
                response
            )
        end
        
        # General API Error
        return APIError(
            get(error_data, "message", "API request failed"),
            response.status,
            get(error_data, "errors", Dict{String,Any}[]),
            response
        )
        
    catch e
        # Fallback for unexpected error formats
        return APIError(
            "Failed to parse error response",
            response.status,
            Dict{String,Any}[],
            response
        )
    end
end

"""
    handle_request_error(e::Exception, endpoint::String)

Central error handling for API requests.
"""
function handle_request_error(e::Exception, endpoint::String)
    if e isa HTTP.StatusError
        error = parse_twitter_error(e.response)
        
        if error isa RateLimitError
            @warn "Rate limit exceeded. Reset at $(error.reset_time)"
            throw(error)
        elseif error isa AuthenticationError
            @warn "Authentication failed for endpoint $endpoint"
            throw(error)
        else
            @error "API request failed: $(error.message)"
            throw(error)
        end
    elseif e isa HTTP.RequestError
        throw(NetworkError("Network error while accessing $endpoint", e))
    else
        rethrow(e)
    end
end

"""
    validate_params(params::Dict{String,Any}, required::Vector{String})

Validates request parameters.
"""
function validate_params(params::Dict{String,Any}, required::Vector{String})
    for field in required
        if !haskey(params, field) || isnothing(params[field])
            throw(ValidationError(
                "Missing required parameter",
                field,
                Dict("required" => required)
            ))
        end
    end
end

# Base.showerror extensions for better error output
function Base.showerror(io::IO, e::RateLimitError)
    if !isnothing(e.reset_time)
        wait_time = max(0, floor(Int, datetime2unix(e.reset_time) - time()))
        print(io, "RateLimitError: $(e.message). Reset in $wait_time seconds. ")
        print(io, "Limit: $(e.limit), Remaining: $(e.remaining)")
    else
        print(io, "RateLimitError: $(e.message)")
    end
end

function Base.showerror(io::IO, e::APIError)
    print(io, "APIError ($(e.status_code)): $(e.message)")
    if !isempty(e.errors)
        print(io, "\nDetails:")
        for (i, error) in enumerate(e.errors)
            print(io, "\n  $i. $(get(error, "message", "Unknown error"))")
        end
    end
end

function Base.showerror(io::IO, e::ValidationError)
    print(io, "ValidationError: $(e.message) (field: $(e.field))")
end 