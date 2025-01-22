# Grok Message Roles
@enum GrokRole begin
    User
    Assistant
    System
end

# Grok Message Structure
struct GrokMessage
    role::GrokRole
    content::String
end

# Rate Limit Information
struct GrokRateLimit
    is_rate_limited::Bool
    message::String
    upsell_info::Union{Dict{String,Any},Nothing}
end

# Grok Chat Options
struct GrokChatOptions
    conversation_id::Union{String,Nothing}
    return_search_results::Bool
    return_citations::Bool
end

# Constructor with default values
GrokChatOptions(;
    conversation_id=nothing,
    return_search_results=false,
    return_citations=false
) = GrokChatOptions(conversation_id, return_search_results, return_citations)

# Grok Chat Response
struct GrokChatResponse
    conversation_id::String
    message::String
    messages::Vector{GrokMessage}
    web_results::Union{Vector{Dict{String,Any}},Nothing}
    metadata::Union{Dict{String,Any},Nothing}
    rate_limit::Union{GrokRateLimit,Nothing}
end

module GrokTypes

using Dates  # Added for DateTime

export GrokRecommendation, GrokConversation

"""
    GrokRecommendation

Represents a Grok recommendation.
"""
struct GrokRecommendation
    id::String
    title::String
    description::String
    score::Float64
    created_at::DateTime
end

"""
    GrokConversation

Represents a Grok conversation.
"""
struct GrokConversation
    id::String
    messages::Vector{Dict{String,Any}}
    context::Dict{String,Any}
    created_at::DateTime
end

end # module 