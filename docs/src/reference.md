# Reference intervals

```julia
ri = reference_interval(values; method=:nonparametric)
partitions = assess_partitions(data; group=:age_group)
curve = reference_curve(age, values)
```

Nonparametric limits follow the 2.5th–97.5th percentile convention of
CLSI EP28 [clsi_ep28](@cite). Also available: parametric, robust MAD,
log-transformed, Box–Cox [boxcox1964](@cite), Horn's Tukey-filter
procedure [horn1998](@cite), and Cole LMS [cole1992](@cite).
Bootstrap confidence intervals are optional.

`assess_partitions` implements Harris–Boyd style evidence [harris1990](@cite)
and **does not** recommend clinical partitions.

`reference_curve` estimates local quantiles against a continuous covariate
instead of forcing bins. `method=:lms` uses a global Box–Cox λ with local
μ and σ (Cole LMS-style).
