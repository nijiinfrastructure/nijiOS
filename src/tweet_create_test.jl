using Test
using TwitterClient

println("Starting Tweet Creation Test...")

# Load environment variables
function load_env_from_file()
    if isfile(".env")
        for line in eachline(".env")
            startswith(line, '#') && continue
            isempty(strip(line)) && continue
            
            if contains(line, "=")
                key, value = split(line, "=", limit=2)
                ENV[key] = strip(strip(value), '"')
            end
        end
    end
end

# Setup
println("\nSetup: Loading environment variables...")
load_env_from_file()
println("✓ Environment variables loaded")

println("\nSetup: Creating scraper...")
scraper = Scraper()
println("✓ Scraper created")

# Test tweet creation
println("\nTest: Creating tweet...")
text = "A test tweet created with Julia on $(Dates.format(now(), "dd.mm.yyyy HH:MM"))"
println("Creating tweet with text: $text")

try
    tweet = create_tweet(scraper, text)
    println("\n✓ Tweet successfully created:")
    println("  ID: $(tweet.id)")
    println("  Text: $(tweet.text)")
    println("  Created at: $(tweet.created_at)")
catch e
    println("\n✗ Tweet creation failed:")
    println("  Error: $e")
    rethrow(e)
end 