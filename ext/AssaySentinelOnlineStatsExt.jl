module AssaySentinelOnlineStatsExt

using AssaySentinel
using OnlineStats
using Statistics

function AssaySentinel.online_series(args...; kwargs...)
    isempty(args) ? Series(Mean(), Variance(), Extrema()) : Series(args...)
end

function AssaySentinel.fit!(d::AssaySentinel.IncrementalCUSUM, o::Variance)
    n = nobs(o)
    n == 0 && return d
    d.n = Int(n)
    d.mean = mean(o)
    v = value(o)
    d.m2 = isfinite(v) ? v * max(n - 1, 1) : 0.0
    d
end

function AssaySentinel.fit!(d::AssaySentinel.IncrementalEWMA, o::Variance)
    n = nobs(o)
    n == 0 && return d
    d.n = Int(n)
    d.mean = mean(o)
    v = value(o)
    d.m2 = isfinite(v) ? v * max(n - 1, 1) : 0.0
    d.z = d.mean
    d.initialized = true
    d
end

function AssaySentinel.update!(o::OnlineStat, m::AssaySentinel.Measurement)
    isfinite(Float64(m.value)) || return o
    fit!(o, Float64(m.value))
    o
end

function AssaySentinel.update!(o::Series, m::AssaySentinel.Measurement)
    isfinite(Float64(m.value)) || return o
    fit!(o, Float64(m.value))
    o
end

function AssaySentinel.update!(d::AssaySentinel.IncrementalCUSUM, o::Variance)
    AssaySentinel.fit!(d, o)
    d
end

end
