# Streaming

```julia
sentinel = Sentinel(baseline)
onalert(sentinel) do alert
    println(alert)
end
for measurement in incoming
    result = update!(sentinel, measurement)
    alert(result) && println(result)
end
```

`IncrementalCUSUM` and `IncrementalEWMA` [roberts1959](@cite) update in
amortized O(1) and do not rescan the full history.

When OnlineStats.jl is loaded, `online_series()` builds a running
`Series(Mean(), Variance(), Extrema())`, and `fit!` / `update!` accept
OnlineStats objects. See [Extensions](@ref).

## Live docs

```bash
julia --project=docs docs/live.jl
```

False-alarm controls: persistence (consecutive signals), cooldown, and a
minimum analytical severity (`:info`, `:watch`, `:warning`, `:critical`).
These are process severities, not clinical terms.

Alert callbacks are generic. Slack/email belong in extensions, not the core.
