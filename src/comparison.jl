# Instrument, method, lot, and site comparison.

"""
    compare_methods(a, b; method=:ba)

Compare paired measurements from two methods.

Methods:
- `:ba` — Bland–Altman (Bland & Altman 1986)
- `:deming` — Deming regression (errors-in-variables)
- `:passing_bablok` — Passing & Bablok (1983)
- `:ols` — ordinary least squares
- `:robust` — Theil–Sen
"""
function compare_methods(a::AbstractVector, b::AbstractVector;
                         method::Symbol = :ba)
    x, y = _xy_finite(a, b)
    n = length(x)
    n < 8 && throw(InsufficientDataError(8, n, "compare_methods"))
    if method === :ba || method === :bland_altman
        return _bland_altman(x, y)
    elseif method === :deming
        return _deming(x, y)
    elseif method === :passing_bablok
        return _passing_bablok(x, y)
    elseif method === :ols
        return _ols_compare(x, y)
    elseif method === :robust
        return _robust_compare(x, y)
    else
        throw(ArgumentError("Unknown comparison method :$method"))
    end
end

compare_instruments(a, b; kwargs...) = compare_methods(a, b; kwargs...)

function _bland_altman(x, y)
    diff = y .- x
    avg = (x .+ y) ./ 2
    bias = mean(diff)
    s = std(diff)
    loa_l, loa_u = bias - 1.96s, bias + 1.96s
    # Proportional bias: slope of diff ~ average
    fit = theil_sen(avg, diff)
    ComparisonResult(:agreement, bias, fit.slope, loa_l, loa_u, 1.0, bias, length(x),
                     :bland_altman,
                     ["Bland–Altman bias $(round(bias; digits=4)); 95% LoA [$(round(loa_l; digits=4)), $(round(loa_u; digits=4))]."],
                     (; sd_diff = s, proportional_slope = fit.slope))
end

function _deming(x, y; λ::Float64 = 1.0)
    n = length(x)
    mx, my = mean(x), mean(y)
    sxx = sum(abs2, x .- mx) / (n - 1)
    syy = sum(abs2, y .- my) / (n - 1)
    sxy = sum((x .- mx) .* (y .- my)) / (n - 1)
    d = syy - λ * sxx
    slope = (d + sqrt(d^2 + 4λ * sxy^2)) / (2sxy)
    isfinite(slope) || (slope = 1.0)
    intercept = my - slope * mx
    ComparisonResult(:regression, intercept, slope - 1, NaN, NaN, slope, intercept, n,
                     :deming,
                     ["Deming slope $(round(slope; digits=4)), intercept $(round(intercept; digits=4))."],
                     (; λ))
end

function _passing_bablok(x, y; α::Float64 = 0.05)
    n = length(x)
    slopes = Float64[]
    sizehint!(slopes, n * (n - 1) ÷ 2)
    for i in 1:(n - 1), j in (i + 1):n
        dx = x[j] - x[i]
        dy = y[j] - y[i]
        if dx != 0
            push!(slopes, dy / dx)
        end
    end
    isempty(slopes) && return ComparisonResult(:regression, 0.0, 0.0, NaN, NaN, 1.0, 0.0, n,
                                               :passing_bablok, ["Degenerate paired data."], EmptyMeta)
    sort!(slopes)
    N = length(slopes)
    K = count(<(-1), slopes)
    slope = slopes[clamp(K + (N + 1) ÷ 2, 1, N)]
    intercept = median(y .- slope .* x)
    # Passing & Bablok (1983) rank CI for the slope
    z = _norm_quantile(1 - α / 2)
    w = n * (n - 1) * (2n + 5) / 18
    C = z * sqrt(w)
    i_lo = clamp(round(Int, K + (N - C) / 2), 1, N)
    i_hi = clamp(round(Int, K + (N + C) / 2), 1, N)
    if i_lo > i_hi
        i_lo, i_hi = i_hi, i_lo
    end
    slope_ci = (slopes[i_lo], slopes[i_hi])
    intercept_ci = (median(y .- slope_ci[2] .* x), median(y .- slope_ci[1] .* x))
    if intercept_ci[1] > intercept_ci[2]
        intercept_ci = (intercept_ci[2], intercept_ci[1])
    end
    ComparisonResult(:regression, intercept, slope - 1, NaN, NaN, slope, intercept, n,
                     :passing_bablok,
                     ["Passing–Bablok slope $(round(slope; digits=4)) (95% CI $(round(slope_ci[1]; digits=4))–$(round(slope_ci[2]; digits=4))), intercept $(round(intercept; digits=4))."],
                     (; K, slope_ci, intercept_ci, α))
end

function _ols_compare(x, y)
    X = hcat(ones(length(x)), x)
    β = X \ y
    ComparisonResult(:regression, β[1], β[2] - 1, NaN, NaN, β[2], β[1], length(x),
                     :ols, ["OLS slope $(round(β[2]; digits=4))."], EmptyMeta)
end

function _robust_compare(x, y)
    fit = theil_sen(x, y)
    ComparisonResult(:regression, fit.intercept, fit.slope - 1, NaN, NaN,
                     fit.slope, fit.intercept, length(x), :theil_sen,
                     ["Theil–Sen slope $(round(fit.slope; digits=4))."], EmptyMeta)
end

"""
    compare_lots(data, lotcol; value=:value)

Estimate whether a lot transition corresponds to location, variance, or
distributional change.
"""
function compare_lots(data, lotcol = :lot; value = :value)
    rows = _table_rows(data)
    lots = String[]
    vals = Float64[]
    for r in rows
        lot = _rowget(r, lotcol)
        lot === nothing && (lot = _rowget(r, :reagent_lot))
        v = _rowget(r, value)
        lot === nothing && continue
        v isa Number && isfinite(Float64(v)) || continue
        push!(lots, string(lot))
        push!(vals, Float64(v))
    end
    uniq = unique(lots)
    length(uniq) < 2 && throw(ArgumentError("compare_lots needs at least two lots"))
    groups = [vals[lots .== ℓ] for ℓ in uniq]
    loc = kruskal_wallis(groups)
    var = levene_bf(groups)
    d = length(uniq) == 2 ? ks_statistic(groups[1], groups[2]) : NaN
    ev = [
        "Location (Kruskal–Wallis) H=$(round(loc.statistic; digits=3)), p=$(round(loc.pvalue; digits=4)).",
        "Variance (Brown–Forsythe) F=$(round(var.statistic; digits=3)), p=$(round(var.pvalue; digits=4)).",
    ]
    isfinite(d) && push!(ev, "Two-lot KS D=$(round(d; digits=3)).")
    (
        lots = uniq,
        location = loc,
        variance = var,
        ks = d,
        evidence = ev,
        shift_suspected = loc.pvalue < 0.05,
        variance_shift = var.pvalue < 0.05,
    )
end

function compare_lots(stream::AssayStream, lotcol = :reagent_lot; kwargs...)
    compare_lots(stream.measurements, lotcol; kwargs...)
end

"""
    compare_sites(data; site, value)
"""
function compare_sites(data; site = :site, value = :value)
    rows = _table_rows(data)
    sites = String[]
    vals = Float64[]
    for r in rows
        s = _rowget(r, site)
        v = _rowget(r, value)
        s === nothing && continue
        v isa Number && isfinite(Float64(v)) || continue
        push!(sites, string(s))
        push!(vals, Float64(v))
    end
    uniq = sort(unique(sites))
    length(uniq) < 2 && throw(ArgumentError("compare_sites needs at least two sites"))
    groups = [vals[sites .== s] for s in uniq]
    loc = kruskal_wallis(groups)
    (
        sites = uniq,
        location = loc,
        evidence = ["Site location H=$(round(loc.statistic; digits=3)), p=$(round(loc.pvalue; digits=4))."],
        site_effect_suspected = loc.pvalue < 0.05,
        notes = "Site differences may reflect instruments, lots, or populations. Association is not causation.",
    )
end
