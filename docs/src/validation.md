# Validation

Every statistical entry point has deterministic tests against known identities
or published critical values where those exist.

| Check | Expected |
| --- | --- |
| Theil–Sen on `y = 2x+1` | slope 2, intercept 1 |
| KS on identical samples | D = 0 |
| 1-Wasserstein of point masses 0 and 2 | 2 |
| Parametric RI of N(100, 5), n=400 | ≈ 90.2–109.8 |
| Bland–Altman on `y = x + 1.5` | bias ≈ 1.5 |
| CUSUM / LR / PELT / Bayesian on a 3σ step at 60 | index within 25 |
| `1-3s` on a +3.5 SD point | triggered at that index |
| Missing / NaN | omitted, never zero-filled |
| `mg/dL` vs `mmol/L` | `UnitMismatchError` |

Simulation harness: `evaluate_detector` measures delay, FPR, sensitivity, and
precision on streams with known `drift_start`.

Limitations of the current suite are listed in `VALIDATION.md` at the
repository root. Stochastic tests use explicit `Xoshiro` seeds.
