@testset "reconstruction: history → story → report" begin
    data = showcase_dataset(; rng = Random.Xoshiro(20260814))
    r = analyze(data.stream; rng = Random.Xoshiro(20260814))
    @test r.reconstruction !== nothing
    rec = r.reconstruction
    @test rec isa Reconstruction
    @test occursin("↓", rec.narrative)
    @test occursin("Stable", rec.narrative)
    kinds = Set(b.kind for b in rec.beats)
    @test !isempty(
        intersect(kinds, Set((:lot_change, :calibration, :drift, :shift, :variance, :qc))),
    )
    @test rec.uncertainty.n_with_uncertainty == length(data.stream)
    @test rec.uncertainty.rms_measurement !== nothing
    @test rec.uncertainty.rms_measurement ≈ 0.4 atol = 1e-12
    @test rec.uncertainty.combined_sd > rec.uncertainty.analytical_sd
    @test rec.lot_analysis !== nothing
    @test rec.instrument_analysis !== nothing
    @test occursin("<svg", rec.charts.timeline)
    @test occursin("<svg", rec.charts.control_chart)
    @test occursin("<svg", rec.charts.provenance)
    @test occursin("<svg", rec.charts.lots)
    @test occursin("<svg", rec.charts.instruments)
    @test !isempty(rec.provenance_graph.nodes)
    @test rec.rng_seed !== nothing
    @test !isempty(rec.input_fingerprint)

    ex = explain(r)
    @test occursin("AssaySentinel reconstruction", ex)
    @test occursin("↓", ex)
    @test occursin("Uncertainty budget", ex)
    @test occursin("Why was this status assigned", ex)
    @test occursin("Statement legend", ex)

    standalone = reconstruct(data.stream; rng = Random.Xoshiro(20260814))
    @test standalone.narrative == rec.narrative
    @test standalone.input_fingerprint == rec.input_fingerprint

    r2 = analyze(data.stream; rng = Random.Xoshiro(20260814))
    @test r2.reconstruction.input_fingerprint == rec.input_fingerprint
    @test r2.reconstruction.narrative == rec.narrative
    @test r2.reconstruction.rng_seed == rec.rng_seed

    mktempdir() do dir
        html = joinpath(dir, "r.html")
        json = joinpath(dir, "r.json")
        assay = joinpath(dir, "r.assay")
        md = joinpath(dir, "r.md")
        report(r, html)
        report(r, json)
        report(r, assay)
        report(r, md)
        html_text = read(html, String)
        @test occursin("<svg", html_text)
        @test occursin("Reconstruction", html_text)
        @test occursin("↓", html_text)
        md_text = read(md, String)
        @test occursin("↓", md_text)
        @test occursin("Uncertainty budget", md_text)

        loaded = load_report(json)
        @test loaded isa AbstractDict
        @test loaded["reconstruction"]["narrative"] == rec.narrative
        @test loaded["reconstruction"]["input_fingerprint"] == rec.input_fingerprint
        @test string(loaded["reconstruction"]["rng_seed"]) == string(rec.rng_seed)
        @test loaded["reconstruction"]["uncertainty"]["n_with_uncertainty"] ==
              rec.uncertainty.n_with_uncertainty
        lex = explain(loaded)
        @test occursin("↓", lex)
        @test occursin("Uncertainty budget", lex)

        roundtrip = load_report(assay)
        @test roundtrip isa QualityReport
        @test roundtrip.reconstruction !== nothing
        @test roundtrip.reconstruction.narrative == rec.narrative
        @test roundtrip.reconstruction.input_fingerprint == rec.input_fingerprint
    end

    parsed = AssaySentinel.json_parse(
        AssaySentinel.json_string(
            Dict(
                "a" => Any[1, 2.5, true, nothing],
                "b" => "line\nnext",
                "c" => Dict("k" => "v"),
            ),
        ),
    )
    @test parsed["a"][1] == 1
    @test parsed["a"][2] == 2.5
    @test parsed["a"][3] === true
    @test parsed["a"][4] === nothing
    @test parsed["b"] == "line\nnext"
    @test parsed["c"]["k"] == "v"
end
