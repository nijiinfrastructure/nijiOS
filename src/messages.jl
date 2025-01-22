module TwitterMessages

using HTTP
using JSON3
using URIs
using ..TwitterTypes
using ..TwitterAPI
using ..TwitterAuth
using ..API
using ..APIv2
using ..Retry

"""
    DirectMessage

Represents a single direct message.
"""
struct DirectMessage
    id::String
    text::String
    sender_id::String
    recipient_id::String
    created_at::String
    media_urls::Union{Vector{String},Nothing}
    sender_screen_name::Union{String,Nothing}
    recipient_screen_name::Union{String,Nothing}
end

"""
    DirectMessageConversation

Represents a DM conversation.
"""
struct DirectMessageConversation
    conversation_id::String
    messages::Vector{DirectMessage}
    participants::Vector{Dict{String,String}}  # id and screen_name
end

"""
    TwitterUser

Represents a Twitter user.
"""
struct TwitterUser
    id::String
    screen_name::String
    name::String
    profile_image_url::String
    description::Union{String,Nothing}
    verified::Union{Bool,Nothing}
    protected::Union{Bool,Nothing}
    followers_count::Union{Int,Nothing}
    friends_count::Union{Int,Nothing}
end

"""
    DirectMessagesResponse

Response to a DM request.
"""
struct DirectMessagesResponse
    conversations::Vector{DirectMessageConversation}
    users::Vector{TwitterUser}
    cursor::Union{String,Nothing}
    last_seen_event_id::Union{String,Nothing}
    trusted_last_seen_event_id::Union{String,Nothing}
    untrusted_last_seen_event_id::Union{String,Nothing}
    inbox_timelines::Union{Dict{String,Any},Nothing}
    user_id::String
end

"""
    parse_direct_message_conversations(data::Dict, user_id::String)::DirectMessagesResponse

Parses the DM API response.
"""
function parse_direct_message_conversations(data::Dict, user_id::String)::DirectMessagesResponse
    try
        inbox_state = get(data, :inbox_initial_state, Dict())
        conversations = get(inbox_state, :conversations, Dict())
        entries = get(inbox_state, :entries, [])
        users = get(inbox_state, :users, Dict())

        # Parse users
        parsed_users = [TwitterUser(
            user.id_str,
            user.screen_name,
            user.name,
            user.profile_image_url_https,
            get(user, :description, nothing),
            get(user, :verified, nothing),
            get(user, :protected, nothing),
            get(user, :followers_count, nothing),
            get(user, :friends_count, nothing)
        ) for user in values(users)]

        # Group messages by conversation
        messages_by_conversation = Dict{String,Vector{Any}}()
        for entry in entries
            if haskey(entry, :message)
                conv_id = entry.message.conversation_id
                if !haskey(messages_by_conversation, conv_id)
                    messages_by_conversation[conv_id] = []
                end
                push!(messages_by_conversation[conv_id], entry.message)
            end
        end

        # Parse conversations
        parsed_conversations = [DirectMessageConversation(
            conv_id,
            parse_direct_messages(get(messages_by_conversation, conv_id, []), users),
            [Dict("id" => p.user_id, 
                 "screen_name" => get(get(users, p.user_id, Dict()), :screen_name, p.user_id))
             for p in conv.participants]
        ) for (conv_id, conv) in conversations]

        return DirectMessagesResponse(
            parsed_conversations,
            parsed_users,
            get(inbox_state, :cursor, nothing),
            get(inbox_state, :last_seen_event_id, nothing),
            get(inbox_state, :trusted_last_seen_event_id, nothing),
            get(inbox_state, :untrusted_last_seen_event_id, nothing),
            get(inbox_state, :inbox_timelines, nothing),
            user_id
        )
    catch e
        @warn "Error parsing DM conversations: $e"
        return DirectMessagesResponse([], [], nothing, nothing, nothing, nothing, nothing, user_id)
    end
end

"""
    parse_direct_messages(messages::Vector{Any}, users::Dict)::Vector{DirectMessage}

Parses a list of direct messages.
"""
function parse_direct_messages(messages::Vector{Any}, users::Dict)::Vector{DirectMessage}
    try
        sorted_messages = sort(messages, by=m -> parse(Int, m.time))
        return [DirectMessage(
            msg.message_data.id,
            msg.message_data.text,
            msg.message_data.sender_id,
            msg.message_data.recipient_id,
            msg.message_data.time,
            extract_media_urls(msg.message_data),
            get(get(users, msg.message_data.sender_id, Dict()), :screen_name, nothing),
            get(get(users, msg.message_data.recipient_id, Dict()), :screen_name, nothing)
        ) for msg in sorted_messages]
    catch e
        @warn "Error parsing DMs: $e"
        return DirectMessage[]
    end
end

"""
    extract_media_urls(message_data::Dict)::Union{Vector{String},Nothing}

Extracts media URLs from a message.
"""
function extract_media_urls(message_data::Dict)::Union{Vector{String},Nothing}
    urls = String[]
    
    # Extract URLs from entities
    if haskey(message_data, :entities)
        entities = message_data.entities
        if haskey(entities, :urls)
            append!(urls, [url.expanded_url for url in entities.urls])
        end
        if haskey(entities, :media)
            append!(urls, [get(media, :media_url_https, get(media, :media_url, nothing))
                         for media in entities.media])
        end
    end
    
    return isempty(urls) ? nothing : urls
end

"""
    get_direct_message_conversations(user_id::String, auth::TwitterAuth, 
                                   cursor::Union{String,Nothing}=nothing)::DirectMessagesResponse

Retrieves direct messages.
"""
function get_direct_message_conversations(user_id::String, auth::TwitterAuth, 
                                        cursor::Union{String,Nothing}=nothing)::DirectMessagesResponse
    if !is_logged_in(auth)
        throw(ErrorException("Authentication required for direct messages"))
    end

    base_url = "https://twitter.com/i/api/graphql/7s3kOODhC5vgXlO0OlqYdA/DMInboxTimeline"
    message_list_url = "https://x.com/i/api/1.1/dm/inbox_initial_state.json"
    
    # URL parameters
    params = Dict{String,String}()
    if !isnothing(cursor)
        params["cursor"] = cursor
    end

    # Execute request
    response = make_request(
        auth,
        "GET",
        message_list_url,
        query=params
    )

    if !response.success
        throw(ErrorException("Error retrieving DMs: $(response.error)"))
    end

    return parse_direct_message_conversations(response.data, user_id)
end

"""
    send_direct_message(auth::TwitterAuth, conversation_id::String, 
                       text::String)::Dict{String,Any}

Sends a direct message.
"""
function send_direct_message(auth::TwitterAuth, conversation_id::String, 
                           text::String)::Dict{String,Any}
    if !is_logged_in(auth)
        throw(ErrorException("Authentication required for direct messages"))
    end

    message_dm_url = "https://x.com/i/api/1.1/dm/new2.json"
    
    payload = Dict(
        "conversation_id" => conversation_id,
        "recipient_ids" => false,
        "text" => text,
        "cards_platform" => "Web-12",
        "include_cards" => 1,
        "include_quote_count" => true,
        "dm_users" => false
    )

    response = make_request(
        auth,
        "POST",
        message_dm_url,
        body=payload
    )

    if !response.success
        throw(ErrorException("Error sending DM: $(response.error)"))
    end

    return response.data
end

export DirectMessage, DirectMessageConversation, TwitterUser, DirectMessagesResponse,
       get_direct_message_conversations, send_direct_message

end # module 

export send_message, get_messages

"""
    send_message(scraper, recipient_id, text)

Sends a direct message to a user.
"""
function send_message(scraper::Scraper, recipient_id, text)
    response = make_request(
        scraper,
        "POST",
        "https://api.twitter.com/2/dm_conversations/with/$recipient_id/messages",
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("text" => text))
    )
    
    return JSON3.read(response.body)
end

"""
    get_messages(scraper; limit=50)

Retrieves the latest direct messages.
"""
function get_messages(scraper::Scraper; limit=50)
    response = make_request(
        scraper,
        "GET",
        "https://api.twitter.com/2/dm_conversations/with_participants/list?limit=$limit",
        ["Content-Type" => "application/json"]
    )
    
    return JSON3.read(response.body)
end 