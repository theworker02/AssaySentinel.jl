@testset "change points" begin
    rng = Random.Xoshiro(11)
    stable = randn(rng, 80)
    cp = detect_changes(stable; method = :cusum)
    @test cp.method === :cusum

    stepped = vcat(randn(rng, 60), randn(rng, 60) .+ 3.0)
    for method in (:cusum, :likelihood, :robust_median, :rolling, :bayesian, :pelt)
        r = detect_changes(stepped; method)
        @test r.method === method
        @test r.detected
        @test !isempty(r.indices)
        @test any(i -> abs(i - 60) ≤ 25, r.indices)
    end
    two = vcat(randn(rng, 40), randn(rng, 40) .+ 3.5, randn(rng, 40) .- 0.5)
    bayes2 = detect_changes(two; method = :bayesian)
    @test bayes2.detected
    @test length(bayes2.indices) >= 1
    @test haskey(bayes2.details, :posterior)
    @test length(bayes2.details.posterior) == 120
    @test_throws ArgumentError detect_changes(stepped; method = :turing)

    auto = detect_changes(stepped; method = :auto)
    @test auto.method !== :auto
    @test !isempty(auto.selection_reason)

    tiny = detect_changes([1.0, 2.0]; method = :auto)
    @test !tiny.detected
end
