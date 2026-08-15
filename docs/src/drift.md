# Drift and change points

```julia
detect_changes(values; method=:auto)
detect_drift(values; kind=:auto)
```

`:auto` inspects sample size, tail weight, missingness, cadence, and control
presence, then **reports the chosen method and why**.

| Method | Role |
| --- | --- |
| `:cusum` | Page CUSUM [page1954](@cite) |
| `:likelihood` | Gaussian mean-change LR / SIC |
| `:pelt` | PELT piecewise mean [killick2012](@cite) |
| `:robust_median` | MAD-standardized CUSUM |
| `:rolling` | Welch window scan |
| `:bayesian` | Offline single-change posterior |
| `:kernel` | Energy-distance scan [szekely2013](@cite) |

Drift kinds: linear (Theil–Sen), sudden, variance (Inclán–Tiao [inclan1994](@cite)),
cyclic (periodogram), distributional (KS), nonlinear (quadratic vs linear).

Results are `DriftResult` / `ChangePointResult` structs, not booleans.

Multivariate matrices use Mahalanobis, PCA Hotelling T², covariance Frobenius
shift, or energy distance.
