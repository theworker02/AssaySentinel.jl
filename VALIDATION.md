# Validation

AssaySentinel treats validation as part of the product. Tests live in `test/`
and are deterministic wherever a closed-form identity exists.

## Identities

- Theil–Sen recovers slope 2 and intercept 1 on `y = 2x + 1`
- Two-sample KS of a sample with itself is 0
- 1-Wasserstein between point masses 0 and 2 is 2
- Parametric 95% interval of N(100, 5) is approximately 90.2–109.8
- Bland–Altman bias on `y = x + 1.5` is approximately 1.5
- Glucose `mg/dL` → `mmol/L` with molar mass 180.156 maps 90 → ~5.0
- `1-3s` fires on a point beyond ±3 SD

## Change-point localization

A 3σ mean step at index 60 in n = 120 is expected within 25 observations for
`:cusum`, `:likelihood`, `:pelt`, `:robust_median`, `:rolling`, and `:bayesian`.

## Simulation harness

`evaluate_detector` estimates sensitivity, false-positive rate, precision, and
mean/median delay on `simulate_assay` streams with known `drift_start`.

## What is not claimed

- Clinical diagnostic accuracy
- Causation from lot / calibration / maintenance timing
- Exact finite-sample p-values for every approximation
- Equivalence to a specific commercial QC middleware package

## Reproducibility

Pass `rng=Xoshiro(seed)` (or `StableRNGs.StableRNG`) into `analyze`,
`simulate_assay`, `reference_interval`, and `evaluate_detector`.
Reports store package version and input fingerprints.
