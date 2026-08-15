@testset "calibration" begin
    x = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
    y = 2.0 .* x .+ 1.0
    c = calibrate(x, y; model = :linear)
    @test c.coefficients[2] ≈ 2 atol = 1e-10
    @test c.r_squared ≈ 1 atol = 1e-10
    @test AssaySentinel.predict_response(c, 3.0) ≈ 7 atol = 1e-10

    cw = calibrate(x, y; model = :weighted_linear)
    @test cw.model === :weighted_linear

    cr = calibrate(x, y; model = :robust)
    @test cr.coefficients[2] ≈ 2 atol = 1e-8

    cp = calibrate(x, y; model = :polynomial, degree = 2)
    @test length(cp.coefficients) == 3

    c2 = calibrate(x, 2.2 .* x .+ 0.5; model = :linear)
    cmp = compare_calibrations(c, c2)
    @test cmp.slope_change ≈ 0.2 atol = 1e-8

    # Natural cubic spline interpolates knots and is cubic between them
    xs = collect(0.0:1.0:4.0)
    ys = xs .^ 3
    cs = calibrate(xs, ys; model = :spline)
    @test cs.model === :spline
    @test AssaySentinel.predict_response(cs, 0.0) ≈ 0 atol = 1e-10
    @test AssaySentinel.predict_response(cs, 2.0) ≈ 8 atol = 1e-10
    @test AssaySentinel.predict_response(cs, 4.0) ≈ 64 atol = 1e-10
    mid = AssaySentinel.predict_response(cs, 1.5)
    linear_mid = 1.0 + 0.5 * (8.0 - 1.0)
    @test abs(mid - 1.5^3) < abs(linear_mid - 1.5^3)
    @test mid ≉ linear_mid atol = 0.05

    diag = calibration_diagnostics(c)
    @test diag.r_squared ≈ 1 atol = 1e-10
    @test diag.runs.n >= 0
    # replicates → lack-of-fit available
    xr = [0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0]
    yr = 2.0 .* xr .+ 1.0 .+ [0.1, -0.1, 0.05, -0.05, 0.0, 0.0, 0.08, -0.08]
    cr = calibrate(xr, yr; model = :linear)
    d2 = calibration_diagnostics(cr)
    @test d2.lack_of_fit !== nothing
    @test d2.lack_of_fit.F >= 0
end
