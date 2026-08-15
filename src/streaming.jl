# Incremental monitoring. Avoid recomputing the full history each observation.

"""
    IncrementalCUSUM

Page CUSUM with Welford moments. O(1) update.
"""
mutable struct IncrementalCUSUM <: AbstractDetector
    n::Int
    mean::Float64
    m2::Float64
    Sp::Float64
    Sm::Float64
    k::Float64
    h::Float64
    last_index::Int
    alarmed::Bool
    direction::Symbol
    persistence::Int
    persist_count::Int
end

function IncrementalCUSUM(; k::Float64 = 0.5, h::Float64 = 5.0, persistence::Int = 2)
    IncrementalCUSUM(0, 0.0, 0.0, 0.0, 0.0, k, h, 0, false, :none, persistence, 0)
end

function fit!(d::IncrementalCUSUM, baseline::Baseline)
    for v in baseline.values
        _welford!(d, v)
    end
    d.Sp = 0.0
    d.Sm = 0.0
    d.alarmed = false
    d
end

function fit!(d::IncrementalCUSUM, values::AbstractVector)
    for v in valid_values(values)
        _welford!(d, v)
    end
    d.Sp = 0.0
    d.Sm = 0.0
    d
end

function _welford!(d::IncrementalCUSUM, x::Float64)
    d.n += 1
    δ = x - d.mean
    d.mean += δ / d.n
    d.m2 += δ * (x - d.mean)
    d
end

function update!(d::IncrementalCUSUM, x::Real)
    isfinite(Float64(x)) || return d
    xv = Float64(x)
    d.last_index += 1
    σ = d.n > 1 ? sqrt(d.m2 / (d.n - 1)) : 1.0
    σ = σ == 0 || !isfinite(σ) ? 1.0 : σ
    z = (xv - d.mean) / σ
    d.Sp = max(0.0, d.Sp + z - d.k)
    d.Sm = max(0.0, d.Sm - z - d.k)
    hit = d.Sp > d.h || d.Sm > d.h
    if hit
        d.persist_count += 1
        d.direction = d.Sp > d.Sm ? :increase : :decrease
    else
        d.persist_count = 0
    end
    d.alarmed = d.persist_count >= d.persistence
    # Adapt baseline slowly when not alarming
    if !d.alarmed
        _welford!(d, xv)
    end
    d
end

function update!(d::IncrementalCUSUM, m::Measurement)
    update!(d, m.value)
end

function result(d::IncrementalCUSUM)
    DriftResult(;
        detected = d.alarmed,
        probability = d.alarmed ? 0.8 : 0.1,
        magnitude = max(d.Sp, d.Sm),
        direction = d.direction,
        start_index = d.last_index,
        detector = :cusum,
        kind = :sudden,
        evidence = d.alarmed ?
                   ["Incremental CUSUM persisted for $(d.persist_count) observation(s)."] :
                   String[],
        details = (; Sp = d.Sp, Sm = d.Sm, n = d.n),
    )
end

"""
    IncrementalEWMA

Roberts (1959) EWMA with incremental variance.
"""
mutable struct IncrementalEWMA <: AbstractDetector
    n::Int
    mean::Float64
    m2::Float64
    z::Float64
    λ::Float64
    L::Float64
    alarmed::Bool
    initialized::Bool
end

function IncrementalEWMA(; λ::Float64 = 0.2, L::Float64 = 3.0)
    IncrementalEWMA(0, 0.0, 0.0, 0.0, λ, L, false, false)
end

function fit!(d::IncrementalEWMA, baseline::Baseline)
    d.mean = baseline.mean
    d.m2 = baseline.sd^2 * max(baseline.n - 1, 1)
    d.n = baseline.n
    d.z = baseline.mean
    d.initialized = true
    d
end

function update!(d::IncrementalEWMA, x::Real)
    isfinite(Float64(x)) || return d
    xv = Float64(x)
    if !d.initialized
        d.mean = xv
        d.z = xv
        d.n = 1
        d.initialized = true
        return d
    end
    d.z = d.λ * xv + (1 - d.λ) * d.z
    # Welford on baseline when quiet
    δ = xv - d.mean
    d.n += 1
    d.mean += δ / d.n
    d.m2 += δ * (xv - d.mean)
    σ = d.n > 1 ? sqrt(d.m2 / (d.n - 1)) : 1.0
    se = σ * sqrt(d.λ / (2 - d.λ))
    d.alarmed = abs(d.z - d.mean) > d.L * se
    d
end

"""
    online_series(stats...)

Build an OnlineStats.jl `Series` for streaming assay values.
Requires `using OnlineStats`.
"""
function online_series(args...; kwargs...)
    throw(
        ArgumentError(
            "online_series requires OnlineStats.jl. Add OnlineStats and run `using OnlineStats`.",
        ),
    )
end

function result(d::IncrementalEWMA)
    DriftResult(;
        detected = d.alarmed,
        probability = d.alarmed ? 0.7 : 0.1,
        magnitude = d.z - d.mean,
        direction = _direction(d.z - d.mean),
        detector = :ewma,
        kind = :linear,
        evidence = d.alarmed ? ["EWMA crossed the ±Lσ_e limit."] : String[],
        details = (; z = d.z, λ = d.λ),
    )
end
