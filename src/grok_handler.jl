"""
    create_grok_conversation(scraper::Scraper)::String

Creates a new Grok conversation and returns the conversation ID.
"""
function create_grok_conversation(scraper::Scraper)::String
    response = make_request(
        scraper,
        "POST",
        "https://x.com/i/api/graphql/6cmfJY3d7EPWuCSXWrkOFg/CreateGrokConversation"
    )
    
    if !response.success
        throw(TwitterAPIError("Failed to create Grok conversation"))
    end
    
    return response.data["data"]["create_grok_conversation"]["conversation_id"]
end

"""
    grok_chat(scraper::Scraper, messages::Vector{GrokMessage}, 
              options::GrokChatOptions=GrokChatOptions())

Conducts a chat with Grok.
"""
function grok_chat(scraper::Scraper, messages::Vector{GrokMessage}, 
                  options::GrokChatOptions=GrokChatOptions())
    
    # Create or use conversation ID
    conversation_id = if isnothing(options.conversation_id)
        create_grok_conversation(scraper)
    else
        options.conversation_id
    end
    
    # Convert Messages to Grok's internal format
    responses = [Dict(
        "message" => msg.content,
        "sender" => msg.role == User ? 1 : 2,
        "promptSource" => msg.role == User ? "" : nothing,
        "fileAttachments" => msg.role == User ? [] : nothing
    ) for msg in messages]
    
    # Create Request Payload
    payload = Dict(
        "responses" => responses,
        "systemPromptName" => "",
        "grokModelOptionId" => "grok-2a",
        "conversationId" => conversation_id,
        "returnSearchResults" => options.return_search_results,
        "returnCitations" => options.return_citations,
        "promptMetadata" => Dict(
            "promptSource" => "NATURAL",
            "action" => "INPUT"
        ),
        "imageGenerationCount" => 4,
        "requestFeatures" => Dict(
            "eagerTweets" => true,
            "serverHistory" => true
        )
    )
    
    response = make_request(
        scraper,
        "POST",
        "$(API_V2)/grok/add_response.json",
        body=payload
    )
    
    if !response.success
        throw(TwitterAPIError("Failed to get Grok response"))
    end
    
    # Parse Response Chunks
    chunks = if haskey(response.data, "text")
        # For streaming responses
        [JSON3.read(chunk) for chunk in split(response.data["text"], "\n") if !isempty(chunk)]
    else
        # For single responses (e.g., rate limiting)
        [response.data]
    end
    
    # Check for rate limits in first chunk
    first_chunk = first(chunks)
    if get(get(first_chunk, "result", Dict()), "responseType", nothing) == "limiter"
        result = first_chunk["result"]
        return GrokChatResponse(
            conversation_id,
            result["message"],
            [messages..., GrokMessage(Assistant, result["message"])],
            nothing,
            nothing,
            GrokRateLimit(
                true,
                result["message"],
                haskey(result, "upsell") ? Dict(
                    "usageLimit" => result["upsell"]["usageLimit"],
                    "quotaDuration" => "$(result["upsell"]["quotaDurationCount"]) $(result["upsell"]["quotaDurationPeriod"])",
                    "title" => result["upsell"]["title"],
                    "message" => result["upsell"]["message"]
                ) : nothing
            )
        )
    end
    
    # Combine all message chunks
    full_message = join([
        chunk["result"]["message"] 
        for chunk in chunks 
        if haskey(get(chunk, "result", Dict()), "message")
    ])
    
    # Extract web results
    web_results = nothing
    for chunk in chunks
        if haskey(get(chunk, "result", Dict()), "webResults")
            web_results = chunk["result"]["webResults"]
            break
        end
    end
    
    return GrokChatResponse(
        conversation_id,
        full_message,
        [messages..., GrokMessage(Assistant, full_message)],
        web_results,
        chunks[1],
        nothing
    )
end

"""
    continue_grok_chat(scraper::Scraper, conversation_id::String, 
                      message::String, options::GrokChatOptions=GrokChatOptions())

Continues an existing Grok chat.
"""
function continue_grok_chat(scraper::Scraper, conversation_id::String, 
                          message::String, options::GrokChatOptions=GrokChatOptions())
    
    messages = [GrokMessage(User, message)]
    options = GrokChatOptions(
        conversation_id=conversation_id,
        return_search_results=options.return_search_results,
        return_citations=options.return_citations
    )
    
    return grok_chat(scraper, messages, options)
end

export create_grok_conversation, grok_chat, continue_grok_chat 

module GrokHandler

using HTTP
using JSON3
using URIs
using ..API
using ..APIv2
using ..Retry
using ..GrokTypes

export get_grok_recommendations, get_grok_conversation

"""
    get_grok_recommendations(scraper; max_results=20)

Retrieves Grok recommendations.
"""
function get_grok_recommendations(scraper; max_results=20)
    response = make_request_v2(
        scraper,
        "GET",
        "https://api.twitter.com/2/grok/recommendations?max_results=$max_results",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

"""
    get_grok_conversation(scraper, conversation_id)

Retrieves a Grok conversation.
"""
function get_grok_conversation(scraper, conversation_id)
    response = make_request_v2(
        scraper,
        "GET",
        "https://api.twitter.com/2/grok/conversations/$conversation_id",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end

end # module 