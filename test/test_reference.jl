@testset "reference intervals" begin
    rng = Random.Xoshiro(7)
    x = 100 .+ 5 .* randn(rng, 400)
    ri = reference_interval(x; method = :parametric, rng, bootstrap = false)
    @test ri.lower ≈ 90.2 atol = 1.5
    @test ri.upper ≈ 109.8 atol = 1.5
    @test occursin("not a clinical", lowercase(ri.notes))

    np = reference_interval(x; method = :nonparametric, rng, bootstrap = false)
    @test np.lower < np.upper

    rb = reference_interval(x; method = :robust, rng, bootstrap = false)
    @test rb.lower < rb.upper

    pos = abs.(x)
    bc = reference_interval(pos; method = :boxcox, rng, bootstrap = false)
    @test bc.lower < bc.upper
    @test haskey(bc.metadata, :lambda)
    horn = reference_interval(x; method = :horn, rng, bootstrap = false)
    @test horn.lower < horn.upper
    lms = reference_interval(pos; method = :lms, rng, bootstrap = false)
    @test lms.lower < lms.upper
    @test lms.metadata.μ > 0

    groups = NamedTuple[]
    for (g, μ) in (("young", 90.0), ("old", 110.0))
        for _ in 1:80
            push!(groups, (; age_group = g, value = μ + randn(rng)))
        end
    end
    part = assess_partitions(groups; group = :age_group, value = :value)
    @test part.may_partition
    @test occursin("not a partitioning recommendation", lowercase(part.notes)) ||
          occursin("statistical evidence only", lowercase(part.notes))

    cov = collect(range(20, 80; length = 80))
    vals = 70 .+ 0.4 .* cov .+ randn(rng, 80)
    curve = reference_curve(cov, vals; span = 0.4)
    @test length(curve.covariate) > 5
    lms_curve = reference_curve(cov, abs.(vals); span = 0.4, method = :lms)
    @test lms_curve.method === :lms
    @test length(lms_curve.quantiles.q0_025) == length(lms_curve.covariate)
end
