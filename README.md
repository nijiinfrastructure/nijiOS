![bannerOS](https://github.com/user-attachments/assets/00003a17-ea18-4cdf-ab81-a3b4cc64ad5c)

# nijiOS 🐦

A powerful, modern Julia client for the Twitter API v2 with AI integration.


## ✨ Features

- 🔐 Full OAuth 1.0a and 2.0 authentication support
- 📝 Complete Twitter API v2 endpoint coverage
- 🚀 Asynchronous request handling
- 💾 Automatic rate limit handling and retries
- 📸 Media upload support (images, videos, GIFs)
- 📊 Comprehensive analytics data access
- 🧵 Thread creation and management
- 🔍 Advanced search capabilities
- 📱 Spaces and live audio support
- 🤖 AI-powered tweet generation using OpenAI

## 🚀 Installation

```julia
using Pkg
Pkg.add("nijiOS")
```

## 🔧 Configuration

Set up your environment variables:

```bash
# Twitter Credentials
TWITTER_USERNAME=your_username
TWITTER_PASSWORD=your_password
TWITTER_BEARER_TOKEN=your_bearer_token

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-4  # or gpt-3.5-turbo
```

## 📚 Quick Start

```julia
using nijiOS

# Create a client
client = create_scraper()

# Login
login!(client, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])

# Regular tweeting
response = send_tweet(client, "Hello from nijiOS! 🚀")

# AI-powered tweeting
prompt = "Write an engaging tweet about Julia programming"
context = Dict(
    "tone" => "technical",
    "hashtags" => ["#JuliaLang", "#Programming"],
    "keywords" => ["performance", "scientific computing"]
)
ai_response = post_ai_tweet(client, prompt; context=context)

# Search tweets
tweets = search_tweets(client, "julia lang", 10)

# Get user information
user = get_user(client, "JuliaLanguage")

# Upload media
media_id = upload_media(client, "image.jpg")

# Logout
logout!(client)
```

## 🤖 AI Tweet Generation

The AI agent uses OpenAI's GPT models to generate engaging tweets:

```julia
# Initialize tweet generator
generator = TweetGenerator()

# Generate a tweet
prompt = "Write about the latest developments in quantum computing"
context = Dict(
    "tone" => "professional",
    "hashtags" => ["#QuantumComputing", "#Tech"],
    "keywords" => ["quantum supremacy", "qubits"]
)

tweet_text = generate_tweet(generator, prompt; context=context)
```

## 🏗️ Architecture

```
nijiOS
├── src/
│   ├── types.jl         # Core types
│   ├── api.jl          # API basics
│   ├── api_v2.jl       # Twitter API v2
│   ├── auth.jl         # Authentication
│   ├── tweets.jl       # Tweet handling
│   ├── ai_agent.jl     # AI tweet generation
│   └── ...
├── test/               # Comprehensive tests
└── docs/              # Documentation
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request



## 🧪 Testing

```julia
using Pkg
Pkg.test("nijiOS")
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Twitter API Documentation
- OpenAI API Documentation
- Julia Community
- Contributors

## 📬 Contact

- GitHub: [@nijiinfrastructure](https://github.com/nijiinfrastructure)
- Twitter: [@nijitech](https://x.com/nijitech)

---

<p align="center">Made with ❤️ in Julia</p>
![bannerOS](https://github.com/user-attachments/assets/00003a17-ea18-4cdf-ab81-a3b4cc64ad5c)
