using Documenter
using nijiOS

makedocs(
    sitename = "nijiOS",
    format = Documenter.HTML(),
    modules = [nijiOS],
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting_started.md",
            "Authentication" => "manual/authentication.md",
            "Tweeting" => "manual/tweeting.md",
            "AI Integration" => "manual/ai_integration.md",
        ],
        "API Reference" => "api.md"
    ]
)

deploydocs(
    repo = "github.com/yourusername/nijiOS.jl.git",
    devbranch = "main"
) 