@testset "panel report reconstruction" begin
    rng = Random.Xoshiro(21)
    panel = AssayPanel("chem-2")
    t0 = DateTime(2026, 1, 1)
    for (analyte, μ, unit) in ((:glucose, 100.0, "mg/dL"), (:creatinine, 1.0, "mg/dL"))
        s = AssayStream(analyte = analyte, unit = unit)
        for i in 1:24
            push!(
                s,
                Measurement(value = μ + 0.4 * randn(rng),
                    timestamp = t0 + Hour(i), unit = unit, control = true),
            )
        end
        push!(panel, s)
    end
    prep = analyze(panel; rng = Random.Xoshiro(21))
    @test prep isa PanelReport
    @test prep.panel == "chem-2"
    @test prep.name == "chem-2"
    @test length(prep.reports) == 2
    @test haskey(prep.reports, :glucose)
    @test prep.reconstruction !== nothing
    @test occursin("<svg", prep.reconstruction.charts.panel)
    @test occursin("<svg", svg_panel_chart(prep.reports))
    @test occursin("not patient risk", lowercase(prep.reconstruction.charts.panel))
    ex = explain(prep)
    @test occursin("panel reconstruction", lowercase(ex))
    @test occursin("glucose", lowercase(ex))
    md = report(prep)
    @test occursin("Units are never pooled", md)
    html = AssaySentinel.html_report(prep)
    @test occursin("</body>", html)
    @test occursin("<svg", html)
    @test occursin("<ul>", html)
    snap = result(prep)
    @test snap.n_analytes == 2
    @test reconstruct(prep) === prep.reconstruction
    standalone = reconstruct(panel; rng = Random.Xoshiro(21))
    @test standalone.input_fingerprint == prep.reconstruction.input_fingerprint

    empty = analyze(AssayPanel("empty"); rng = Random.Xoshiro(1))
    @test empty isa PanelReport
    @test isempty(empty.reports)
    @test occursin("</body>", AssaySentinel.html_report(empty))

    mixed = AssayPanel("mixed-units")
    g = AssayStream(analyte = :glucose, unit = "mg/dL")
    n = AssayStream(analyte = :sodium, unit = "mmol/L")
    for i in 1:12
        push!(g, Measurement(value = 100.0, timestamp = t0 + Hour(i), unit = "mg/dL"))
        push!(n, Measurement(value = 140.0, timestamp = t0 + Hour(i), unit = "mmol/L"))
    end
    push!(mixed, g)
    push!(mixed, n)
    mrep = analyze(mixed; rng = Random.Xoshiro(3))
    @test isnan(mrep.reconstruction.uncertainty.combined_sd)
    @test occursin("different units", mrep.reconstruction.uncertainty.notes)

    mktempdir() do dir
        htmlp = joinpath(dir, "p.html")
        jsonp = joinpath(dir, "p.json")
        assayp = joinpath(dir, "p.assay")
        report(prep, htmlp)
        report(prep, jsonp)
        report(prep, assayp)
        loaded = load_report(jsonp)
        @test loaded isa AbstractDict
        @test loaded["kind"] == "panel"
        @test loaded["n_analytes"] == 2
        roundtrip = load_report(assayp)
        @test roundtrip isa PanelReport
        @test roundtrip.name == "chem-2"
        @test reconstruct(roundtrip).narrative == prep.reconstruction.narrative
    end
end
