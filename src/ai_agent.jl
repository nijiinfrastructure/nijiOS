module AIAgent

using OpenAI
using JSON3
using Dates

export generate_tweet, TweetGenerator

struct TweetGenerator
    api_key::String
    model::String
    max_tokens::Int
    temperature::Float64
end

"""
    TweetGenerator(; api_key=ENV["OPENAI_API_KEY"], model="gpt-4", max_tokens=280, temperature=0.7)

Creates a new TweetGenerator with the specified OpenAI configuration.
"""
function TweetGenerator(; 
    api_key=ENV["OPENAI_API_KEY"],
    model="gpt-4",
    max_tokens=280,
    temperature=0.7
)
    TweetGenerator(api_key, model, max_tokens, temperature)
end

"""
    generate_tweet(generator::TweetGenerator, prompt::String; context::Dict=Dict())

Generates a tweet using OpenAI's API based on the given prompt and context.
"""
function generate_tweet(generator::TweetGenerator, prompt::String; context::Dict=Dict())
    client = OpenAI.Client(generator.api_key)
    
    # Build the system message with tweet guidelines
    system_message = """
    You are a professional Twitter content creator. Create engaging tweets that:
    - Are concise and impactful
    - Use appropriate emojis
    - Include relevant hashtags
    - Stay within Twitter's character limit
    - Match the given context and tone
    """
    
    # Create the messages array
    messages = [
        Dict("role" => "system", "content" => system_message),
        Dict("role" => "user", "content" => prompt)
    ]
    
    # Add context if provided
    if !isempty(context)
        context_msg = "Context: " * JSON3.write(context)
        push!(messages, Dict("role" => "user", "content" => context_msg))
    end
    
    # Make the API call
    response = create_chat(
        client,
        generator.model;
        messages=messages,
        temperature=generator.temperature,
        max_tokens=generator.max_tokens
    )
    
    # Extract and clean the generated tweet
    tweet_text = first(response.choices).message.content
    return strip(tweet_text)
end

end # module 