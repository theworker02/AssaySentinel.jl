@testset "CLI" begin
    @test AssaySentinel.main(["version"]) == 0
    @test AssaySentinel.main(["help"]) == 0
    @test AssaySentinel.main(["doctor"]) == 0
    @test AssaySentinel.main(["simulate", "--n=80"]) == 0
    @test AssaySentinel.main(["nope"]) == 2
end
