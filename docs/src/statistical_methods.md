# Statistical methods

This page is the citable methodology index. Implementations prefer published
estimators over ad-hoc thresholds. Assumptions and limitations are listed with
each method.

## Change detection

- **CUSUM** [page1954](@cite). Two-sided standardized CUSUM with allowance `k`
  (default 0.5) and decision interval `h` (default 5). Localization uses the
  CUSUM path `argmax |∑(x−x̄)|`. Assumes approximately independent observations
  after standardization. Sensitive to misspecified σ on short series.
- **Likelihood / SIC scan.** Gaussian mean-change log-likelihood ratio versus a
  single-mean model, penalized by `log n`. Assumes normality and a single
  dominant change.
- **PELT** [killick2012](@cite). Standardized L2 piecewise-mean cost with MBIC
  penalty `3 log n`. `min_size` constrains candidate segments only; the
  surviving set `R` is pruned with the paper's inequality (`K = 0` for RSS).
  Multiple changes.
- **Bayesian product partition** [fearnhead2006](@cite). Geometric hazard
  prior; Gaussian observations with known variance and a weak conjugate
  prior on the segment mean. Forward–backward smoothing gives a posterior
  mass at every index; MAP segmentation can report multiple changes.
- **Turing (extension).** Hierarchical Gaussian changepoint sampled with
  Metropolis–Hastings when Turing.jl is loaded (`method=:turing`).
- **`:auto`.** Chooses among robust CUSUM, likelihood, Fearnhead, and PELT
  using n, tails, missingness, cadence, control-like series, and the number
  of sequential CUSUM crossings (multiple crossings → PELT).
- **Energy scan** [szekely2013](@cite). Univariate energy distance between left
  and right segments.

`:auto` documents its decision (n, tails, missingness, cadence, controls).

## Drift

- Linear: Theil–Sen [theil1950](@cite) [sen1968](@cite).
- Variance: Inclán–Tiao ICSS [inclan1994](@cite); 5% Brownian-bridge critical
  value 1.358.
- Cyclic: periodogram peak / Fisher-like g.
- Distributional: two-sample KS with Stephens-style p-value approximation.

## QC

Westgard multirules [westgard1981](@cite); Levey–Jennings geometry
[levey1950](@cite). Rules are data, not a monolith.

## Comparison and batches

Bland–Altman [bland1986](@cite); Passing–Bablok [passing1983](@cite); Deming;
Kruskal–Wallis [kruskal1952](@cite); Brown–Forsythe [brown1974](@cite);
parametric empirical-Bayes ComBat [johnson2007](@cite).

## Reference limits

CLSI EP28 nonparametric convention [clsi_ep28](@cite); Harris–Boyd partitioning
evidence [harris1990](@cite). Output is statistical, not a clinical
recommendation.

## Distances

1-Wasserstein (quantile matching); Jensen–Shannon [lin1991](@cite); energy
distance [szekely2013](@cite).

## Outliers

Normalized MAD [rousseeuw1993](@cite); Tukey IQR fences. Detection annotates;
deletion is a separate, explicit policy.

## Sentinel Score

Documented linear penalty combination. Components and weights are always
stored. The score is analytical stability, not patient risk.
