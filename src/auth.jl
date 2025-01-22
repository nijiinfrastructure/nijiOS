using HTTP
using JSON
using Base64
using Dates
using CookieJar
using TwitterClient
using JSON3
using URIs
using ..Retry
using ..Types
using ..API
using ..APIv2
using MbedTLS
using Random
using UUIDs

# Auth Types
abstract type AbstractTwitterAuth end

struct TwitterGuestAuth <: AbstractTwitterAuth
    guest_token::Union{String,Nothing}
    guest_created_at::Union{DateTime,Nothing}
    cookies::CookieJar.Jar
end

struct TwitterUserAuth <: AbstractTwitterAuth
    username::String
    password::String
    email::Union{String,Nothing}
    bearer_token::Union{String,Nothing}
    csrf_token::Union{String,Nothing}
    cookies::CookieJar.Jar
end

struct TwitterAPIAuth <: AbstractTwitterAuth
    api_key::String
    api_secret::String
    access_token::String
    access_secret::String
    bearer_token::Union{String,Nothing}
    cookies::CookieJar.Jar
end

"""
    TwitterAuth

Main structure for Twitter authentication supporting different auth methods.
"""
mutable struct TwitterAuth
    guest_auth::Union{TwitterGuestAuth,Nothing}
    user_auth::Union{TwitterUserAuth,Nothing}
    api_auth::Union{TwitterAPIAuth,Nothing}
    cookies::CookieJar.Jar
    rate_limiter::RateLimiter
    last_token_refresh::DateTime
    
    function TwitterAuth()
        new(nothing, nothing, nothing, CookieJar.Jar(), 
            RateLimiter(), now() - Minute(60))
    end
end

# Constants
const BEARER_TOKEN = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs=1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

# New constants for Login Flow
const LOGIN_URL = "https://api.twitter.com/1.1/onboarding/task.json"
const FLOW_TOKEN_URL = "https://api.twitter.com/1.1/onboarding/begin_flow.json"

"""
    LoginFlowResponse

Structure for the login flow response
"""
struct LoginFlowResponse
    status::String
    subtask::Union{Dict{String,Any},Nothing}
    flow_token::Union{String,Nothing}
end

"""
    update_cookie_jar!(jar::CookieJar.Jar, response::HTTP.Response)

Updates the cookie jar with Set-Cookie headers from the response.
"""
function update_cookie_jar!(jar::CookieJar.Jar, response::HTTP.Response)
    if haskey(response.headers, "Set-Cookie")
        cookies = response.headers["Set-Cookie"]
        if cookies isa Vector
            for cookie in cookies
                CookieJar.setcookie!(jar, cookie)
            end
        else
            CookieJar.setcookie!(jar, cookies)
        end
    end
end

"""
    create_guest_auth()

Creates a new guest authentication session.
"""
function create_guest_auth()::TwitterGuestAuth
    jar = CookieJar.Jar()
    
    headers = [
        "Authorization" => "Bearer $BEARER_TOKEN",
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    ]
    
    response = HTTP.post(
        "https://api.twitter.com/1.1/guest/activate.json",
        headers
    )
    
    if response.status != 200
        throw(ErrorException("Guest auth failed: $(response.status)"))
    end
    
    update_cookie_jar!(jar, response)
    
    result = JSON.parse(String(response.body))
    guest_token = result["guest_token"]
    
    TwitterGuestAuth(guest_token, now(), jar)
end

"""
    initiate_login_flow(auth::TwitterAuth)

Initiates the login flow and retrieves the first flow token.
"""
function initiate_login_flow(auth::TwitterAuth)
    # Flow Token Request Data
    flow_data = Dict(
        "flow_name" => "login",
        "input_flow_data" => Dict(
            "flow_context" => Dict(
                "debug_overrides" => Dict(),
                "start_location" => Dict("location" => "unknown")
            )
        )
    )

    # Request Headers
    headers = [
        "Authorization" => "Bearer $BEARER_TOKEN",
        "Content-Type" => "application/json",
        "User-Agent" => "TwitterBot/1.0"
    ]

    # Send Flow Token Request
    response = HTTP.post(
        FLOW_TOKEN_URL,
        headers,
        JSON.json(flow_data)
    )

    if response.status != 200
        throw(ErrorException("Failed to initiate login flow: $(response.status)"))
    end

    result = JSON.parse(String(response.body))
    return result["flow_token"]
end

"""
    execute_login_step(auth::TwitterAuth, flow_token::String, subtask_inputs::Vector{Dict})

Executes a single step in the login flow.
"""
function execute_login_step(auth::TwitterAuth, flow_token::String, subtask_inputs::Vector{Dict})::LoginFlowResponse
    # Login Step Request Data
    step_data = Dict(
        "flow_token" => flow_token,
        "subtask_inputs" => subtask_inputs
    )

    # Request Headers
    headers = [
        "Authorization" => "Bearer $BEARER_TOKEN",
        "Content-Type" => "application/json",
        "User-Agent" => "TwitterBot/1.0"
    ]

    # Cookie Header hinzufügen wenn vorhanden
    if !isempty(auth.cookies)
        headers = vcat(headers, ["Cookie" => join(values(auth.cookies), "; ")])
    end

    # Login Step Request senden
    response = HTTP.post(
        LOGIN_URL,
        headers,
        JSON.json(step_data)
    )

    if response.status != 200
        throw(ErrorException("Login step failed: $(response.status)"))
    end

    # Cookies aus Response extrahieren
    if haskey(response.headers, "Set-Cookie")
        for cookie in response.headers["Set-Cookie"]
            push!(auth.cookies, cookie)
        end
    end

    result = JSON.parse(String(response.body))
    
    # Flow Status überprüfen
    if haskey(result, "status")
        if result["status"] == "error"
            throw(ErrorException("Login error: $(result["message"])"))
        end
    end

    return LoginFlowResponse(
        get(result, "status", "unknown"),
        get(result, "subtask", nothing),
        get(result, "flow_token", nothing)
    )
end

"""
    login!(auth::TwitterAuth, username::String, password::String, email::Union{String,Nothing}=nothing)

Executes the complete login flow.
"""
function login!(auth::TwitterAuth, username::String, password::String, email::Union{String,Nothing}=nothing)
    # Ensure passwords are not logged
    @info "Attempting to log in user"

    # Guest Auth initialisieren falls nicht vorhanden
    if isnothing(auth.guest_auth)
        auth.guest_auth = create_guest_auth()
    end

    # Flow Token holen
    flow_token = initiate_login_flow(auth)

    # Username Step
    username_response = execute_login_step(auth, flow_token, [
        Dict(
            "subtask_id" => "LoginEnterUserIdentifierSSO",
            "settings_list" => Dict(
                "setting_responses" => [
                    Dict(
                        "key" => "user_identifier",
                        "value" => username
                    )
                ]
            )
        )
    ])

    if isnothing(username_response.flow_token)
        throw(ErrorException("Username step failed"))
    end

    # Password Step
    password_response = execute_login_step(auth, username_response.flow_token, [
        Dict(
            "subtask_id" => "LoginEnterPassword",
            "enter_password" => Dict(
                "password" => password
            )
        )
    ])

    if isnothing(password_response.flow_token)
        throw(ErrorException("Password step failed"))
    end

    # Account Verification falls notwendig
    if !isnothing(password_response.subtask) && 
        get(password_response.subtask, "subtask_id", "") == "LoginAcid"
        
        if isnothing(email)
            throw(ErrorException("Email verification required but no email provided"))
        end

        email_response = execute_login_step(auth, password_response.flow_token, [
            Dict(
                "subtask_id" => "LoginAcid",
                "enter_text" => Dict(
                    "text" => email
                )
            )
        ])

        if isnothing(email_response.flow_token)
            throw(ErrorException("Email verification failed"))
        end

        flow_token = email_response.flow_token
    else
        flow_token = password_response.flow_token
    end

    # CSRF Token holen
    csrf_token = get_csrf_token(auth)

    # User Auth erstellen
    auth.user_auth = TwitterUserAuth(
        username,
        password,
        email,
        BEARER_TOKEN,
        csrf_token,
        auth.cookies
    )

    if login_successful
        @info "User logged in successfully"
    else
        throw(AuthenticationError("Invalid credentials"))
    end

    return auth
end

"""
    login_with_api!(auth::TwitterAuth, credentials::Dict{String,String})

Performs login with API credentials.
"""
function login_with_api!(auth::TwitterAuth, credentials::Dict{String,String})
    # API Auth Setup
    api_auth = TwitterAPIAuth(
        credentials["TWITTER_API_KEY"],
        credentials["TWITTER_API_SECRET_KEY"],
        credentials["TWITTER_ACCESS_TOKEN"],
        credentials["TWITTER_ACCESS_TOKEN_SECRET"],
        nothing,
        auth.cookies
    )
    
    # Bearer Token holen
    auth_string = base64encode("$(api_auth.api_key):$(api_auth.api_secret)")
    
    response = HTTP.post(
        "https://api.twitter.com/oauth2/token",
        ["Authorization" => "Basic $auth_string"],
        "grant_type=client_credentials"
    )
    
    if response.status == 200
        result = JSON.parse(String(response.body))
        api_auth = @set api_auth.bearer_token = result["access_token"]
        auth.api_auth = api_auth
    else
        throw(ErrorException("API auth failed: $(response.status)"))
    end
    
    return auth
end

# Helper Functions
function get_flow_token(auth::TwitterAuth)::String
    # Implementation for Flow Token retrieval
end

function get_csrf_token(auth::TwitterAuth)::String
    response = HTTP.get(
        "https://api.twitter.com/1.1/account/verify_credentials.json",
        ["Authorization" => "Bearer $BEARER_TOKEN"]
    )

    if haskey(response.headers, "x-csrf-token")
        return response.headers["x-csrf-token"]
    end

    throw(ErrorException("Failed to get CSRF token"))
end

function is_logged_in(auth::TwitterAuth)::Bool
    !isnothing(auth.user_auth) || !isnothing(auth.api_auth)
end

function logout!(auth::TwitterAuth)
    auth.user_auth = nothing
    auth.api_auth = nothing
    auth.cookies = CookieJar.Jar()
end

# Neue Funktionen für Token Management

"""
    should_refresh_token(auth::TwitterAuth)::Bool

Checks if token should be refreshed.
"""
function should_refresh_token(auth::TwitterAuth)::Bool
    if isnothing(auth.user_auth) || isnothing(auth.user_auth.bearer_token)
        return false
    end
    
    # Token alle 45 Minuten erneuern
    token_age = now() - auth.last_token_refresh
    return Dates.value(token_age) / 1000 > 45 * 60
end

"""
    refresh_token!(auth::TwitterAuth)

Refreshes the Bearer Token.
"""
function refresh_token!(auth::TwitterAuth)
    if !is_logged_in(auth)
        throw(ErrorException("Not logged in"))
    end
    
    response = HTTP.post(
        "https://api.twitter.com/1.1/oauth2/token",
        ["Content-Type" => "application/x-www-form-urlencoded"],
        "grant_type=client_credentials"
    )
    
    if response.status == 200
        result = JSON.parse(String(response.body))
        if haskey(result, "access_token")
            if !isnothing(auth.user_auth)
                auth.user_auth = @set auth.user_auth.bearer_token = result["access_token"]
            end
            auth.last_token_refresh = now()
        end
    else
        throw(ErrorException("Token refresh failed: $(response.status)"))
    end
    
    return auth
end

module Auth

using Random, UUIDs, HTTP, JSON3, Dates

export TwitterUserAuth, install_to!, post_tweet

mutable struct TwitterUserAuth
    bearer_token::String
    guest_token::Union{String,Nothing}
    guest_created_at::Union{DateTime,Nothing}
    cookies::Dict{String,String}
    api_key::Union{String,Nothing}
    api_secret::Union{String,Nothing}
    access_token::Union{String,Nothing}
    access_secret::Union{String,Nothing}
    user_profile::Union{Dict{String,Any},Nothing}
    
    function TwitterUserAuth(bearer_token::String)
        new(bearer_token, nothing, nothing, Dict{String,String}(), 
            nothing, nothing, nothing, nothing, nothing)
    end
end

include("auth/helpers.jl")
include("auth/flow.jl")
include("auth/login.jl")
include("auth/post.jl")

end # module 