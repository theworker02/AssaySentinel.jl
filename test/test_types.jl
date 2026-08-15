@testset "types and streams" begin
    m = Measurement(value = 101.2, timestamp = DateTime(2026, 8, 4, 14, 32),
                    batch = "B104", lot = "R22", control = true, unit = "mg/dL")
    @test m.value == 101.2
    @test m.reagent_lot == "R22"
    @test m.control
    @test m.uncertainty === nothing

    stream = AssayStream(analyte = :glucose, unit = "mg/dL", instrument = "Analyzer-A")
    push!(stream, m)
    @test length(stream) == 1
    @test stream.measurements[1].instrument == "Analyzer-A"

    @test_throws UnitMismatchError push!(stream, Measurement(value = 5.6, unit = "mmol/L"))

    c = ControlSample(name = "QC-Level-1", target = 100.0, sd = 2.0)
    @test c.sd == 2.0
    @test_throws ArgumentError ControlSample(name = "bad", target = 1.0, sd = 0.0)

    panel = AssayPanel("chem")
    push!(panel, stream)
    @test haskey(panel.streams, :glucose)

    site = Site("Lab-A"; instruments = [Instrument("Analyzer-A")])
    study = Study("Multi-site"; sites = [site])
    @test length(study.sites) == 1

    a = Alert(message = "watch", severity = :watch)
    @test a.severity === :watch
    @test_throws ArgumentError Alert(message = "x", severity = :lethal)
end
