@testset "simulation, analyze, reports" begin
    rng = Random.Xoshiro(17)
    sim = simulate_assay(; n = 200, drift = :step, drift_start = 120, rng)
    @test length(sim.stream) == 200
    @test sim.truth.drift === :step

    r = analyze(sim.stream; rng)
    @test r isa QualityReport
    @test r.analyte === :analyte_x
    @test occursin("not a diagnostic", lowercase(r.safety_notice))
    text = sprint(show, r)
    @test occursin("AssaySentinel Report", text)
    ex = explain(r)
    @test occursin("Why was this status assigned", ex)
    @test occursin("Score components", ex)

    mktempdir() do dir
        p = joinpath(dir, "r.md")
        save(r, p)
        @test isfile(p)
        save(r, joinpath(dir, "r.html"))
        save(r, joinpath(dir, "r.json"))
        assay = joinpath(dir, "r.assay")
        save(r, assay)
        loaded = load_report(assay)
        @test loaded.analyte === r.analyte
    end

    ev = evaluate_detector(:likelihood; nrep = 4, n = 160, drift_start = 90,
        rng = Random.Xoshiro(19))
    @test ev.sensitivity ≥ 0.5

    demo = showcase_dataset(; rng = Random.Xoshiro(21))
    @test length(demo.stream) == 1460
    @test length(demo.truth.lots) == 3
end
