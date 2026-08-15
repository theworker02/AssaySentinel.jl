# Batch effects

Detection and correction are separate operations. Correction never runs by
default and never mutates the original table.

```julia
effects = detect_batch_effects(dataset; batch=:plate, biological_group=:condition)
corrected = correct_batch_effects(dataset; method=:combat, batch=:plate)
```

Detection uses Kruskal–Wallis [kruskal1952](@cite) on batch, optionally after
removing experimental-group location. The interpretation states whether leftover
batch signal looks technical, mixed, or grouping-aligned.

`:combat` is parametric empirical-Bayes ComBat after Johnson, Li &
Rabinovic [johnson2007](@cite): batch location `γ` and scale `δ²` are
shrunk toward hyperparameters estimated from the batch-level moments.
Pass `biological_group` to protect an experimental design. The
transformation (including `gamma_star`, `delta2_star`, and `_hyper`) is
returned so it can be stored in provenance.

Other corrections: `:quantile` (batch-wise quantile matching) and `:ruv`
(control-anchored unwanted-variation removal). Multi-feature ComBat is
`correct_batch_effects(X, batch)` where `X` is observations × features
and shrinkage is across features, as in the original paper.
