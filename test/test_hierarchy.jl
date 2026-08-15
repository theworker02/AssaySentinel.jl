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
    @test_throws InsufficientDataError hierarchical_sites([1.0, 2.0], ["A", "B"])
    @test_throws ArgumentError hierarchical_sites(ones(20), fill("only", 20))

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
    report = analyze(study, streams; rng = Random.Xoshiro(7))
    @test report isa StudyReport
    @test report.schema_version == string(SCHEMA_VERSION)
    @test length(report.site_reports) == 2

    base_a = Baseline(fill(100.0, 30); unit = "mg/dL")
    base_b = Baseline(fill(100.0, 30); unit = "mg/dL")
    mon = StudySentinel(Dict("Lab-A" => base_a, "Lab-B" => base_b); name = "study")
    @test mon isa StudySentinel
    t = DateTime(2026, 6, 1)
    update!(mon, "Lab-A", Measurement(value = 100.2, timestamp = t, unit = "mg/dL"))
    @test_throws ArgumentError update!(mon, "Lab-Z",
        Measurement(value = 1.0, timestamp = t, unit = "mg/dL"))
end
