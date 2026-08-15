@testset "statistical primitives" begin
    @test valid_values([1.0, missing, NaN, 2.0, nothing]) == [1.0, 2.0]
    @test 0 ∉ valid_values([missing, NaN])

    x = 1.0:10
    y = 2.0 .* x .+ 1
    fit = theil_sen(collect(x), collect(y))
    @test fit.slope ≈ 2 atol = 1e-10
    @test fit.intercept ≈ 1 atol = 1e-10

    a = randn(Random.Xoshiro(1), 200)
    b = randn(Random.Xoshiro(2), 200) .+ 3
    wt = welch_t(a, b)
    @test wt.pvalue < 1e-6

    @test ks_statistic(a, a) ≈ 0 atol = 1e-12
    @test wasserstein1d([0.0], [2.0]) ≈ 2 atol = 1e-10
    @test energy_distance([0.0, 0.0], [1.0, 1.0]) > 0

    @test robust_mad(ones(20)) == 0
    x = [1, 2, 3, 4, 100]
    @test robust_mad(x) < std(x)

    @test fingerprint([1.0, 2.0]) == fingerprint([1.0, 2.0])
    @test fingerprint([1.0, 2.0]) != fingerprint([1.0, 2.1])
end
