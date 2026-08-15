# Calibration

```julia
curve = calibrate(concentrations, responses; model=:weighted_linear)
compare_calibrations(curve1, curve2)
```

Models: `:linear`, `:weighted_linear`, `:polynomial`, `:robust` (Theil–Sen),
`:spline` (natural cubic spline with continuous second derivatives),
`:fourpl`.

`calibration_diagnostics` reports residual SD, relative error, a runs test
on residual signs, 4PL parameter names, and lack-of-fit when replicates
exist.

`compare_calibrations` reports slope change, intercept change, residual shift,
and a practical magnitude on a shared concentration grid. It does not claim a
clinical impact.
