# Extensions

The core package is stdlib-only. Optional integrations load when you
`using` the corresponding package.

## Makie

```julia
using AssaySentinel, Makie
levey_jennings(values, QCSpec(100.0, 2.0))
lot_chart(rows; lot=:lot, value=:value)
instrument_chart(rows; instrument=:instrument, value=:value)
forest_chart(hierarchical_sites(values, sites))
```

## Unitful / Measurements

`Measurement` values can wrap `Unitful` quantities and
`Measurements.Measurement` uncertainties. The core still stores a
numeric value plus an explicit `uncertainty` field; the extensions
unwrap those types at the boundary.

## Turing

`detect_changes(x; method=:turing)` runs a hierarchical Gaussian
changepoint model. Default `sampler=:mh` uses a discrete cut.
`sampler=:nuts` uses a continuous cut so Hamiltonian Monte Carlo can run.
`model=:multiple` with `ncuts` fits more than two piecewise means.

```julia
using AssaySentinel, Turing
detect_changes(values; method=:turing, rng=Xoshiro(1))
detect_changes(values; method=:turing, model=:multiple, ncuts=3, sampler=:nuts)
```

The default `:bayesian` method does **not** need Turing. It is the
Fearnhead (2006) product-partition posterior and supports multiple
changes in the core package.

## OnlineStats

```julia
using AssaySentinel, OnlineStats

s = online_series()                 # Series(Mean(), Variance(), Extrema())
update!(s, Measurement(value=101.2, timestamp=now()))

d = IncrementalCUSUM()
fit!(d, Variance() )                # after you have fitted the Variance
```

`online_series` and the `fit!` / `update!` methods are no-ops (they
throw a load error) until OnlineStats is loaded.

## Live documentation

```bash
julia --project=docs docs/live.jl
```

That serves a rebuild-on-save Documenter site (LiveServer `servedocs`).
The published site is <https://theworker02.github.io/AssaySentinel.jl>.
