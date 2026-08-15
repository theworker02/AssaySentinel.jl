@testset "provenance and units" begin
    recs = AssaySentinel.ProvenanceRecord[]
    r = record_step!(recs; operation = :test, func = "f", input_fingerprint = "abc",
                     notes = "hello")
    @test r.package_version == string(AssaySentinel.PACKAGE_VERSION)
    @test !isempty(AssaySentinel.provenance_lines(recs))
    g = AssaySentinel.provenance_graph(recs)
    @test length(g.nodes) == 1

    @test AssaySentinel.normalize_unit("mg/dl") == "mg/dL"
    @test AssaySentinel.convert_unit(90.0, "mg/dL", "mmol/L"; molar_mass = 180.156) ≈ 5.0 atol = 0.05
    @test_throws UnitMismatchError check_units("mg/dL", "mmol/L")
    @test check_units("mg/dL", "mg/dl") === nothing

    tl = EventTimeline()
    record!(tl, CalibrationEvent(DateTime(2026, 1, 1), "C1"))
    record!(tl, LotChangeEvent(DateTime(2026, 1, 3), "R22"; from_lot = "R21"))
    attr = AssaySentinel.attribute_change(DateTime(2026, 1, 4), tl)
    @test attr.score > 0
    @test occursin("not evidence of causation", attr.statement)
end
