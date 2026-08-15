@testset "streaming sentinel" begin
    rng = Random.Xoshiro(13)
    base = Baseline(100 .+ 0.8 .* randn(rng, 80); unit = "mg/dL")
    sent =
        Sentinel(base; detector = IncrementalCUSUM(; persistence = 2), cooldown = Hour(1))
    alerts = Alert[]
    onalert(sent) do a
        push!(alerts, a)
    end
    for i in 1:30
        update!(sent, 100 + 0.8 * randn(rng))
    end
    for i in 1:40
        update!(sent, 108 + 0.8 * randn(rng))
    end
    @test !isempty(sent.alerts) || !isempty(alerts)

    ewma = IncrementalEWMA()
    fit!(ewma, base)
    update!(ewma, 100.1)
    @test result(ewma) isa DriftResult

    @test_throws ArgumentError online_series()
end
