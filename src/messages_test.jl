module TwitterMessagesTest

using Test
using Dates
using ..TwitterMessages
using ..TwitterAuth
using ..TwitterTestUtils

@testset "DirectMessage Tests" begin
    # Setup
    let scraper = get_test_scraper()
        test_user_id = nothing
        test_conversation_id = nothing
        should_skip_v2_tests = false

        try
            # Initialize test data
            profile = get_profile(ENV["TWITTER_USERNAME"], scraper.auth)
            test_user_id = profile.user_id
            
            # Get first conversation for tests
            conversations = get_direct_message_conversations(test_user_id, scraper.auth)
            if !isempty(conversations.conversations)
                test_conversation_id = conversations.conversations[1].conversation_id
            else
                @warn "No conversations found"
                should_skip_v2_tests = true
            end
        catch e
            @warn "Error initializing test data: $e"
            should_skip_v2_tests = true
        end

        @testset "Fetch DM Conversations" begin
            if !should_skip_v2_tests && !isnothing(test_user_id)
                conversations = get_direct_message_conversations(test_user_id, scraper.auth)
                
                @test !isnothing(conversations)
                @test conversations isa DirectMessagesResponse
                @test conversations.conversations isa Vector{DirectMessageConversation}
                @test conversations.users isa Vector{TwitterUser}
            else
                @warn "Test skipped: Required test data not available"
            end
        end

        @testset "Verify DM Conversation Structure" begin
            if !should_skip_v2_tests && !isnothing(test_user_id)
                conversations = get_direct_message_conversations(test_user_id, scraper.auth)
                
                if !isempty(conversations.conversations)
                    conversation = first(conversations.conversations)
                    
                    # Test conversation structure
                    @test hasfield(typeof(conversation), :conversation_id)
                    @test hasfield(typeof(conversation), :messages)
                    @test hasfield(typeof(conversation), :participants)
                    
                    # Test participant structure
                    if !isempty(conversation.participants)
                        participant = first(conversation.participants)
                        @test haskey(participant, "id")
                        @test haskey(participant, "screen_name")
                    end
                    
                    # Test message structure
                    if !isempty(conversation.messages)
                        message = first(conversation.messages)
                        @test hasfield(typeof(message), :id)
                        @test hasfield(typeof(message), :text)
                        @test hasfield(typeof(message), :sender_id)
                        @test hasfield(typeof(message), :recipient_id)
                        @test hasfield(typeof(message), :created_at)
                    end
                end
            else
                @warn "Test skipped: Required test data not available"
            end
        end

        @testset "Handle DM Send Failure Gracefully" begin
            if !should_skip_v2_tests
                invalid_conversation_id = "invalid-id"
                
                @test_throws Exception send_direct_message(
                    scraper.auth,
                    invalid_conversation_id,
                    "test message"
                )
            else
                @warn "Test skipped: Required test data not available"
            end
        end

        @testset "Send and Receive DM" begin
            if !should_skip_v2_tests && !isnothing(test_conversation_id)
                # Send test message
                test_message = "Test message $(now())"
                response = send_direct_message(
                    scraper.auth,
                    test_conversation_id,
                    test_message
                )
                
                @test !isnothing(response)
                
                # Wait briefly for message to arrive
                sleep(2)
                
                # Check message in conversation
                conversations = get_direct_message_conversations(test_user_id, scraper.auth)
                conversation = findfirst(c -> c.conversation_id == test_conversation_id,
                                      conversations.conversations)
                
                if !isnothing(conversation)
                    latest_message = isempty(conversation.messages) ? nothing : first(conversation.messages)
                    if !isnothing(latest_message)
                        @test latest_message.text == test_message
                    end
                end
            else
                @warn "Test skipped: Required test data not available"
            end
        end

        @testset "DM with Media" begin
            if !should_skip_v2_tests && !isnothing(test_conversation_id)
                conversations = get_direct_message_conversations(test_user_id, scraper.auth)
                
                if !isempty(conversations.conversations)
                    conversation = first(conversations.conversations)
                    
                    # Search for messages with media
                    media_messages = filter(m -> !isnothing(m.media_urls), 
                                         conversation.messages)
                    
                    if !isempty(media_messages)
                        message = first(media_messages)
                        @test !isempty(message.media_urls)
                        @test all(url -> startswith(url, "https://"), message.media_urls)
                    end
                end
            else
                @warn "Test skipped: Required test data not available"
            end
        end
    end
end

end # module 