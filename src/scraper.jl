module TwitterScraper

using HTTP
using JSON
using ..TwitterRateLimiter
using ..Types

export ScraperOptions, Scraper, create_scraper, init_scraper!

mutable struct ScraperOptions
    proxy_url::Union{String,Nothing}
    timeout::Int
    retry_count::Int
end

# Standard constructor for options
ScraperOptions() = ScraperOptions(nothing, 30, 3)

"""
    Scraper

Manages the HTTP session.
"""
mutable struct Scraper
    cookies::HTTP.Cookies.CookieJar
    rate_limiter::Any  # Type annotation changed to Any
    
    function Scraper()
        new(HTTP.Cookies.CookieJar())  # Rate limiter will be set later
    end
end

"""
    login!(scraper::Scraper, username::String, password::String, 
           email::Union{String,Nothing}=nothing)

Führt den Login-Prozess für den Scraper durch.
"""
function login!(scraper::Scraper, username::String, password::String, 
                email::Union{String,Nothing}=nothing)
    scraper.auth.password_auth = PasswordAuth(username, password, email)
    
    # Login-Request durchführen
    try
        response = HTTP.post(
            "$(API_BASE)/auth/login",
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "username" => username,
                "password" => password
            )),
            client=scraper.client
        )
        
        if response.status == 200
            # Cookies aus Response extrahieren und speichern
            cookies = HTTP.cookies(response)
            for cookie in cookies
                scraper.auth.cookies[cookie.name] = cookie.value
            end
            return true
        end
    catch e
        @error "Login fehlgeschlagen" exception=e
        return false
    end
    
    return false
end

"""
    is_logged_in(scraper::Scraper)

Überprüft, ob der Scraper eingeloggt ist.
"""
function is_logged_in(scraper::Scraper)
    !isempty(scraper.auth.cookies) || !isnothing(scraper.auth.bearer_token)
end

"""
    logout!(scraper::Scraper)

Loggt den Scraper aus und löscht die Authentifizierungsdaten.
"""
function logout!(scraper::Scraper)
    empty!(scraper.auth.cookies)
    scraper.auth.bearer_token = nothing
    scraper.auth.password_auth = nothing
    return true
end

"""
    get_cookies(scraper::Scraper)

Gibt die aktuellen Cookies des Scrapers zurück.
"""
function get_cookies(scraper::Scraper)
    scraper.auth.cookies
end

"""
    set_cookies!(scraper::Scraper, cookies::Dict{String,String})

Setzt die Cookies für den Scraper.
"""
function set_cookies!(scraper::Scraper, cookies::Dict{String,String})
    scraper.auth.cookies = cookies
end

"""
    clear_cookies!(scraper::Scraper)

Löscht alle Cookies des Scrapers.
"""
function clear_cookies!(scraper::Scraper)
    empty!(scraper.auth.cookies)
end

"""
    create_scraper() -> Scraper

Creates a new Scraper instance with initialized cookies and rate limiter.

# Example
```julia
scraper = create_scraper()
```
"""
function create_scraper()
    return Scraper()
end

"""
    init_scraper!(scraper::Scraper)

Initializes an existing Scraper with new default values.
"""
function init_scraper!(scraper::Scraper)
    scraper.cookies = HTTP.Cookies.CookieJar()
    scraper.rate_limiter = RateLimiter()
    return scraper
end

end # module 