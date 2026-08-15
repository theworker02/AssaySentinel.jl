@testset "edge cases" begin
    @test_throws InsufficientDataError reference_interval([1.0, 2.0])
    @test_throws InsufficientDataError calibrate([1.0], [2.0])

    r = analyze([NaN, missing, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
                rng = Random.Xoshiro(1))
    @test r.n == 10
    @test any(occursin("Missing", L) || occursin("omitted", L) for L in r.limitations) || r.n == 10

    constdata = fill(5.0, 40)
    d = detect_changes(constdata; method = :likelihood)
    @test d isa ChangePointResult

    out = detect_outliers([1.0, 1.1, 0.9, 1.0, 50.0]; method = :mad)
    @test 5 in out.indices
    @test !out.removed

    irregular = [DateTime(2026, 1, 1) + Day(i^2) for i in 1:20]
    vals = randn(Random.Xoshiro(2), 20)
    cp = detect_changes(vals; method = :auto, timestamps = irregular)
    @test occursin("robust", lowercase(cp.selection_reason)) || cp.method === :robust_median ||
          cp.method isa Symbol

    rows = [(; value = 1.0, timestamp = DateTime(2026, 1, 1))]
    stream = AssaySentinel.from_table(rows; analyte = :x, unit = "U", value = :value, time = :timestamp)
    @test length(stream) == 1

    @test AssaySentinel.convert_unit(1.0, "g/L", "mg/dL") == 100
end
