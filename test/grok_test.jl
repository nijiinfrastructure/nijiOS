@testset "Grok Integration Tests" begin
    scraper = Scraper()
    login!(scraper, ENV["TWITTER_USERNAME"], ENV["TWITTER_PASSWORD"])
    
    @testset "Basic Grok Chat" begin
        messages = [GrokMessage(User, "Hello, how are you?")]
        response = grok_chat(scraper, messages)
        
        @test !isnothing(response.conversation_id)
        @test !isempty(response.message)
        @test length(response.messages) >= 2  # At least question and answer
    end
    
    @testset "Grok Chat with Search Results" begin
        messages = [GrokMessage(User, "What's new in quantum computing?")]
        options = GrokChatOptions(return_search_results=true)
        response = grok_chat(scraper, messages, options)
        
        @test !isnothing(response.web_results)
        @test !isempty(response.web_results)
    end
    
    @testset "Grok Chat Continuation" begin
        # Start initial chat
        initial_messages = [GrokMessage(User, "Let's talk about AI")]
        initial_response = grok_chat(scraper, initial_messages)
        
        # Continue chat
        continued_response = continue_grok_chat(
            scraper,
            initial_response.conversation_id,
            "Tell me more about machine learning"
        )
        
        @test continued_response.conversation_id == initial_response.conversation_id
        @test !isempty(continued_response.message)
    end
    
    @testset "Rate Limit Handling" begin
        # Send many requests to trigger rate limit
        messages = [GrokMessage(User, "Test message")]
        
        for _ in 1:30  # More than the rate limit
            response = grok_chat(scraper, messages)
            
            if !isnothing(response.rate_limit) && response.rate_limit.is_rate_limited
                @test !isnothing(response.rate_limit.message)
                @test !isnothing(response.rate_limit.upsell_info)
                break
            end
        end
    end
end 