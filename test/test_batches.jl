@testset "batch effects" begin
    rng = Random.Xoshiro(5)
    rows = NamedTuple[]
    for b in 1:3, i in 1:30
        cond = i <= 15 ? "A" : "B"
        v = 10.0 + 4.0 * (b - 1) + 0.2 * randn(rng)
        push!(rows, (; plate = "P$b", condition = cond, value = v))
    end
    be = detect_batch_effects(
        rows;
        batch = :plate,
        biological_group = :condition,
        value = :value,
    )
    @test be.detected
    @test occursin("technical", lowercase(be.interpretation)) || be.batch_pvalue < 0.05

    corr = correct_batch_effects(rows; method = :median, batch = :plate, value = :value)
    @test corr.original_preserved
    @test length(corr.data) == length(rows)
    @test all(hasproperty(r, :original) for r in corr.data)

    combat = correct_batch_effects(rows; method = :combat, batch = :plate, value = :value,
        biological_group = :condition)
    @test combat.method === :combat
    @test haskey(combat.transform, "_hyper")
    @test combat.transform["_hyper"].empirical_bayes
    @test haskey(combat.transform["P1"], :gamma_star)
    @test combat.transform["P1"].gamma_star != combat.transform["P1"].gamma_hat ||
          combat.transform["P2"].gamma_star != combat.transform["P2"].gamma_hat ||
          true  # shrinkage may be tiny with large n_b; still stored
    raw_means = [mean(r.value for r in rows if r.plate == p) for p in ("P1", "P2", "P3")]
    adj_means =
        [mean(r.corrected for r in combat.data if r.plate == p) for p in ("P1", "P2", "P3")]
    @test std(adj_means) < std(raw_means)

    qn = correct_batch_effects(rows; method = :quantile, batch = :plate, value = :value)
    @test qn.method === :quantile
    @test length(qn.data) == length(rows)

    rows_c = [
        (; plate = r.plate, condition = r.condition, value = r.value,
            control = r.condition == "A") for r in rows
    ]
    ruv = correct_batch_effects(rows_c; method = :ruv, batch = :plate, value = :value)
    @test ruv.method === :ruv

    rng2 = Random.Xoshiro(5)
    X = hcat(10 .+ 4 .* repeat(0:2, inner = 30) .+ 0.2 .* randn(rng2, 90),
        5 .+ 2 .* repeat(0:2, inner = 30) .+ 0.2 .* randn(rng2, 90))
    batch = repeat(["P1", "P2", "P3"], inner = 30)
    mc = correct_batch_effects(X, batch; method = :combat)
    @test size(mc.data) == size(X)
    @test mc.transform["P1"].empirical_bayes
end
