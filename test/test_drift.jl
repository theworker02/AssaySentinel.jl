@testset "drift" begin
    rng = Random.Xoshiro(3)
    x = collect(1:80)
    linear = 100 .+ 0.08 .* x .+ 0.3 .* randn(rng, 80)
    d = detect_drift(linear; kind = :linear)
    @test d isa DriftResult
    @test d.detected
    @test d.direction === :increase

    step = vcat(100 .+ 0.4 .* randn(rng, 50), 108 .+ 0.4 .* randn(rng, 50))
    s = detect_drift(step; kind = :sudden)
    @test s.detected
    @test s.start_index !== nothing

    var = vcat(randn(rng, 60), 3 .* randn(rng, 60))
    v = detect_drift(var; kind = :variance)
    @test v.detected

    auto = detect_drift(step; kind = :auto)
    @test auto.detector === :auto
    @test auto.kind !== :auto

    X = hcat(randn(rng, 80), randn(rng, 80))
    X[41:80, :] .+= 2.5
    mv = detect_drift(X; method = :mahalanobis)
    @test mv.kind === :multivariate
end
