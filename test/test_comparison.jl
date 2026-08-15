@testset "comparison" begin
    rng = Random.Xoshiro(9)
    x = 50 .+ 20 .* rand(rng, 40)
    y = x .+ 1.5 .+ 0.3 .* randn(rng, 40)
    ba = compare_methods(x, y; method = :ba)
    @test ba.bias ≈ 1.5 atol = 0.3
    @test ba.loa_lower < ba.bias < ba.loa_upper

    pb = compare_methods(x, y; method = :passing_bablok)
    @test pb.slope ≈ 1 atol = 0.15
    @test haskey(pb.details, :slope_ci)
    @test pb.details.slope_ci[1] <= pb.slope <= pb.details.slope_ci[2]
    @test haskey(pb.details, :intercept_ci)

    dm = compare_methods(x, y; method = :deming)
    @test dm.slope ≈ 1 atol = 0.15

    lots = NamedTuple[]
    for (lot, μ) in (("R21", 100.0), ("R22", 104.0))
        for _ in 1:40
            push!(lots, (; lot, value = μ + 0.5 * randn(rng)))
        end
    end
    lc = compare_lots(lots, :lot)
    @test lc.shift_suspected

    sites = [
        (; site = i <= 40 ? "A" : "B", value = (i <= 40 ? 10.0 : 12.0) + 0.2 * randn(rng))
        for i in 1:80
    ]
    sc = compare_sites(sites; site = :site, value = :value)
    @test sc.site_effect_suspected
    @test occursin("not causation", sc.notes)

    base = Baseline(randn(rng, 80))
    cur = randn(rng, 80) .+ 2
    d = compare_distribution(base, cur; method = :ks)
    @test d.pvalue !== nothing
    @test d.pvalue < 0.01
end
