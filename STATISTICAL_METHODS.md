# Statistical methods

Canonical citations for algorithms implemented in AssaySentinel.jl. See also
`docs/src/statistical_methods.md` and `docs/src/refs.bib`.

| Topic | Implementation | Primary references |
| --- | --- | --- |
| CUSUM | `detect_changes(...; method=:cusum)`, `IncrementalCUSUM` | Page 1954 |
| PELT | `method=:pelt` | Killick, Fearnhead & Eckley 2012 |
| Variance change | Inclán–Tiao ICSS | Inclán & Tiao 1994 |
| Energy distance | `:kernel`, `:energy` | Székely & Rizzo 2013 |
| Theil–Sen | linear drift, robust calibration | Theil 1950; Sen 1968 |
| EWMA | `IncrementalEWMA` | Roberts 1959 |
| Westgard rules | `westgard_rules` | Westgard et al. 1981 |
| Levey–Jennings | `levey_jennings_data` | Levey & Jennings 1950 |
| Bland–Altman | `compare_methods(...; method=:ba)` | Bland & Altman 1986 |
| Passing–Bablok | `method=:passing_bablok` | Passing & Bablok 1983 (slope/intercept CI) |
| Kruskal–Wallis | batches, sites, lots | Kruskal & Wallis 1952 |
| Brown–Forsythe | lot variance | Brown & Forsythe 1974 |
| ComBat | `correct_batch_effects(...; method=:combat)` | Johnson, Li & Rabinovic 2007 (parametric EB) |
| Bayesian CP | `method=:bayesian` | Fearnhead 2006 product partition |
| Turing CP | `method=:turing` (extension) | MH or NUTS; k-cut with `model=:multiple` |
| Natural cubic spline | `calibrate(...; model=:spline)` | interpolating cubic, not piecewise linear |
| Reference intervals | `reference_interval` | CLSI EP28-A3c; Box & Cox 1964; Horn 1998; Cole & Green 1992 |
| Partitioning | `assess_partitions` | Harris & Boyd 1990 |
| Hierarchical sites | `hierarchical_sites` | DerSimonian & Laird 1986; Higgins & Thompson 2002; Higgins, Thompson & Spiegelhalter 2009 |
| MAD outliers | `detect_outliers` | Rousseeuw & Croux 1993 |
| Jensen–Shannon | `compare_distribution(...; method=:js)` | Lin 1991 |

## Assumptions (shared)

- Observations are treated as a time-ordered measurement process, not as a
  clinical cohort.
- Independence is assumed after the documented standardization unless a method
  says otherwise.
- p-values for KS, t, and χ² use well-known approximations; they are not exact
  permutation tests unless stated.
- Core Bayesian change-point is Fearnhead's product-partition model
  (multiple changes). Hierarchical MCMC is the optional Turing extension.

## Limitations

- `:auto` is a documented heuristic, not an oracle.
- Univariate ComBat shrinks across batches; multi-gene microarray ComBat
  (shrinkage across features) is the same formulas with a feature index.
- Passing–Bablok returns a rank-based 95% CI for slope and intercept.
- Multivariate energy distance is O(n²) and intended for moderate n.
