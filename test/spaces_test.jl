using Test
using TwitterClient
using TwitterClient.TwitterSpaces
using Dates

@testset "Twitter Spaces Tests" begin
    @testset "Space ID Generation" begin
        id = generate_random_id()
        @test length(id) == 36
        @test occursin(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", id)
    end
    
    @testset "Audio Space Fetching" begin
        scraper = get_scraper()
        
        variables = AudioSpaceByIdVariables(
            "1234567890",  # Space ID
            false,         # is_ticket_holder
            false,         # is_admin
            false          # is_member
        )
        
        @test_throws TwitterAPIError fetch_audio_space_by_id(variables, scraper.auth)
    end
    
    @testset "Space Object Construction" begin
        space = AudioSpace(
            "space123",
            "live",
            "Test Space",
            now(),
            nothing,
            now(),
            nothing,
            ["host1", "host2"],
            ["participant1"],
            ["speaker1", "speaker2"],
            100,
            false
        )
        
        @test space.id == "space123"
        @test space.state == "live"
        @test space.host_ids == ["host1", "host2"]
        @test space.subscriber_count == 100
        @test !space.is_ticketed
    end
end 