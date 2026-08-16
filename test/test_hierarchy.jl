@testset "hierarchy and study sentinel" begin
    rng = Random.Xoshiro(13)
    sites = String[]
    vals = Float64[]
    for (lab, μ) in (("Lab-A", 100.0), ("Lab-B", 104.0), ("Lab-C", 101.0))
        for _ in 1:20
            push!(sites, lab)
            push!(vals, μ + 0.8 * randn(rng))
        end
    end
    hier = hierarchical_sites(vals, sites; rng = Random.Xoshiro(13))
    @test hier isa HierarchicalSiteResult
    @test length(hier.sites) == 3
    @test hier.attribution in (:global, :site_specific, :mixed, :stable)
    @test occursin("not causation", hier.notes)
    @test 0 <= hier.i2 <= 100
    @test hier.prediction_lo < hier.prediction_hi
    @test all(s -> s.se >= 0, hier.sites)
    @test any(s -> s.site == "Lab-B", hier.sites)
    forest = svg_forest_chart(hier)
    @test occursin("<svg", forest)
    @test occursin("Lab-A", forest)
    @test occursin("not causation", lowercase(forest)) || occursin("Not causation", forest)

    dirty = copy(vals)
    dirty[1] = NaN
    dirty[2] = Inf
    hier2 = hierarchical_sites(dirty, sites; rng = Random.Xoshiro(13))
    @test length(hier2.sites) == 3
    @test_throws ArgumentError hierarchical_sites(vals, sites;
        timestamps = [now()], rng = Random.Xoshiro(1))

    @test_throws InsufficientDataError hierarchical_sites([1.0, 2.0], ["A", "B"])
    @test_throws ArgumentError hierarchical_sites(ones(20), fill("only", 20))
    @test_throws ArgumentError hierarchical_sites(vals, sites; method = :turing)

    rows = [
        (; site = sites[i], value = vals[i], timestamp = DateTime(2026, 1, 1) + Hour(i))
        for i in eachindex(vals)
    ]
    hier_t = hierarchical_sites(rows; site = :site, rng = Random.Xoshiro(13))
    @test hier_t.grand_mean ≈ hier.grand_mean atol = 1e-8

    flat_sites = vcat(fill("A", 16), fill("B", 16))
    flat_vals = vcat(fill(100.0, 16), fill(104.0, 16))
    flat = hierarchical_sites(flat_vals, flat_sites; rng = Random.Xoshiro(1))
    @test flat.attribution === :stable
    @test flat.i2 > 50
    @test !flat.global_drift.detected

    study = Study("Multi-site"; sites = [Site("Lab-A"), Site("Lab-B")])
    streams = Dict{String, AssayStream}()
    for (name, μ) in (("Lab-A", 100.0), ("Lab-B", 103.0))
        s = AssayStream(analyte = :glucose, unit = "mg/dL", site = name)
        t0 = DateTime(2026, 1, 1)
        for i in 1:24
            push!(
                s,
                Measurement(value = μ + 0.5 * randn(rng),
                    timestamp = t0 + Hour(i), unit = "mg/dL"),
            )
        end
        streams[name] = s
    end
    srep = analyze(study, streams; rng = Random.Xoshiro(7))
    @test srep isa StudyReport
    @test srep.schema_version == string(SCHEMA_VERSION)
    @test length(srep.site_reports) == 2
    @test srep.reconstruction !== nothing
    @test occursin("not causation", lowercase(explain(srep)))
    ex = explain(srep)
    @test occursin("I²", ex) || occursin("I2", explain(srep.hierarchy)) ||
          occursin("i2", lowercase(ex))
    md = report(srep)
    @test occursin("prediction interval", md)
    @test occursin("Lab-A", md)
    html = AssaySentinel.html_report(srep)
    @test occursin("</body>", html)
    @test occursin("<svg", html)
    @test occursin("<ul>", html)
    snap = summary(srep)
    @test snap.n_sites == 2

    standalone = reconstruct(study, streams; rng = Random.Xoshiro(7))
    @test standalone isa Reconstruction
    @test reconstruct(srep) === srep.reconstruction

    mktempdir() do dir
        htmlp = joinpath(dir, "study.html")
        jsonp = joinpath(dir, "study.json")
        assayp = joinpath(dir, "study.assay")
        mdp = joinpath(dir, "study.md")
        report(srep, htmlp)
        report(srep, jsonp)
        save(srep, assayp)
        save(srep, mdp)
        loaded = load_report(jsonp)
        @test loaded["attribution"] == string(srep.hierarchy.attribution)
        @test loaded["i2"] == srep.hierarchy.i2
        roundtrip = load_report(assayp)
        @test roundtrip isa StudyReport
        @test roundtrip.reconstruction.narrative == srep.reconstruction.narrative
    end

    base_a = Baseline(fill(100.0, 30); unit = "mg/dL")
    base_b = Baseline(fill(100.0, 30); unit = "mg/dL")
    mon = StudySentinel(Dict("Lab-A" => base_a, "Lab-B" => base_b);
        name = "study", concordance_cooldown = Hour(6))
    @test mon isa StudySentinel
    t = DateTime(2026, 6, 1)
    update!(mon, "Lab-A", Measurement(value = 100.2, timestamp = t, unit = "mg/dL"))
    @test_throws ArgumentError update!(mon, "Lab-Z",
        Measurement(value = 1.0, timestamp = t, unit = "mg/dL"))
    n_alerts = 0
    for i in 1:40
        ti = t + Minute(i)
        ra = update!(mon, "Lab-A",
            Measurement(value = 130.0, timestamp = ti, unit = "mg/dL"))
        rb = update!(mon, "Lab-B",
            Measurement(value = 130.0, timestamp = ti, unit = "mg/dL"))
        (ra isa Alert || rb isa Alert) && (n_alerts += 1)
    end
    @test !isempty(mon.alerts)
    @test length(mon.alerts) == 1
    later = update!(mon, "Lab-A",
        Measurement(value = 130.0, timestamp = t + Hour(7), unit = "mg/dL"))
    laterb = update!(mon, "Lab-B",
        Measurement(value = 130.0, timestamp = t + Hour(7), unit = "mg/dL"))
    @test length(mon.alerts) >= 2
    snap2 = result(mon)
    @test snap2.n_sites == 2
    @test snap2.n_concordance_alerts == length(mon.alerts)
end
