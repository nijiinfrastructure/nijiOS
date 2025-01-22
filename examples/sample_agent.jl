using TwitterClient
using Dotenv

# load enviroment varia
Dotenv.config()

function main()
    # Client ini
    scraper = Scraper()
    
    # V1 Login
    login!(scraper, 
        ENV["TWITTER_USERNAME"],
        ENV["TWITTER_PASSWORD"]
    )
    
    # Tweet with
    send_tweet!(scraper,
        "Wann werden wir AGI (Artificial General Intelligence) erreichen? 🤖",
        poll = Dict(
            "options" => [
                "2025 🗓️",
                "2026 📅", 
                "2027 🛠️",
                "2030+ 🚀"
            ],
            "duration_minutes" => 1440
        )
    )
    
    # Tweet g
    tweet = get_tweet(scraper, "1856441982811529619")
    println(tweet)
end

main() 