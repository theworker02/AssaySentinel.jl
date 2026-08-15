# Reference-interval toolkit. Statistical evidence only — not clinical advice.

"""
    reference_interval(values; method=:nonparametric, rng, α=0.05, unit="")

Methods:
- `:nonparametric` — 2.5th–97.5th percentiles (CLSI EP28-style)
- `:parametric` — mean ± 1.96 SD
- `:robust` — median ± 1.96 × normalized MAD
- `:transformed` — log-scale parametric, back-transformed
- `:boxcox` — Box–Cox profile-likelihood transform, then parametric limits
- `:horn` — Tukey fences then nonparametric limits on the remaining sample
- `:lms` — Cole LMS (λ, μ, σ) 2.5th–97.5th quantiles
"""
function reference_interval(values::AbstractVector;
                            method::Symbol = :nonparametric,
                            rng::AbstractRNG = Random.default_rng(),
                            α::Float64 = 0.05,
                            unit::AbstractString = "",
                            bootstrap::Bool = true,
                            nboot::Int = 400)
    x = valid_values(values)
    n = length(x)
    n < 20 && throw(InsufficientDataError(20, n, "reference_interval"))
    notes = "Statistical reference limits only. Not a clinical decision interval."
    meta = EmptyMeta
    if method === :nonparametric
        lo = sample_quantile(x, 0.025)
        hi = sample_quantile(x, 0.975)
    elseif method === :parametric
        μ, σ = mean(x), std(x)
        lo, hi = μ - 1.96σ, μ + 1.96σ
    elseif method === :robust
        med = median(x)
        s = robust_mad(x)
        lo, hi = med - 1.96s, med + 1.96s
    elseif method === :transformed
        if any(<=(0), x)
            throw(ArgumentError("transformed reference intervals require strictly positive values"))
        end
        lx = log.(x)
        μ, σ = mean(lx), std(lx)
        lo, hi = exp(μ - 1.96σ), exp(μ + 1.96σ)
    elseif method === :boxcox
        any(<=(0), x) && throw(ArgumentError("Box–Cox reference intervals require strictly positive values"))
        λ = boxcox_lambda(x)
        y = boxcox.(x, λ)
        μ, σ = mean(y), std(y)
        lo = inv_boxcox(μ - 1.96σ, λ)
        hi = inv_boxcox(μ + 1.96σ, λ)
        meta = (; lambda = λ)
        notes *= " Box–Cox λ=$(round(λ; digits=3))."
    elseif method === :horn
        kept, nout = _horn_filter(x)
        lo = sample_quantile(kept, 0.025)
        hi = sample_quantile(kept, 0.975)
        meta = (; n_removed = nout, n_kept = length(kept))
        notes *= " Horn robust filter removed $nout observation(s)."
    elseif method === :lms
        any(<=(0), x) && throw(ArgumentError("LMS reference intervals require strictly positive values"))
        fit = lms_fit(x)
        lo = lms_quantile(fit.μ, fit.σ, fit.λ, -1.96)
        hi = lms_quantile(fit.μ, fit.σ, fit.λ, 1.96)
        meta = fit
        notes *= " LMS λ=$(round(fit.λ; digits=3)), μ=$(round(fit.μ; digits=3)), σ=$(round(fit.σ; digits=3))."
    else
        throw(ArgumentError("Unknown reference-interval method :$method"))
    end
    lci = uci = nothing
    if bootstrap && n >= 30
        lci = bootstrap_ci(x, v -> _ri_edge(v, method, true); nboot, rng, α)
        uci = bootstrap_ci(x, v -> _ri_edge(v, method, false); nboot, rng, α)
    end
    if n < 120
        notes *= " CLSI EP28 recommends n ≥ 120 for nonparametric limits; n=$n is smaller."
    end
    ReferenceInterval(lo, hi, lci, uci, method, n, String(unit), notes, meta)
end

function _horn_filter(x::AbstractVector{<:Real})
    q1, q3 = sample_quantile(x, 0.25), sample_quantile(x, 0.75)
    iqr = q3 - q1
    lo, hi = q1 - 1.5 * iqr, q3 + 1.5 * iqr
    kept = [Float64(v) for v in x if lo <= v <= hi]
    isempty(kept) && return collect(Float64, x), 0
    kept, length(x) - length(kept)
end

function _ri_edge(x, method, lower::Bool)
    if method === :nonparametric
        return sample_quantile(x, lower ? 0.025 : 0.975)
    elseif method === :parametric
        μ, σ = mean(x), std(x)
        return lower ? μ - 1.96σ : μ + 1.96σ
    elseif method === :robust
        med = median(x)
        s = robust_mad(x)
        return lower ? med - 1.96s : med + 1.96s
    elseif method === :boxcox
        any(<=(0), x) && return NaN
        λ = boxcox_lambda(x)
        y = boxcox.(x, λ)
        μ, σ = mean(y), std(y)
        return inv_boxcox(lower ? μ - 1.96σ : μ + 1.96σ, λ)
    elseif method === :horn
        kept, _ = _horn_filter(x)
        return sample_quantile(kept, lower ? 0.025 : 0.975)
    elseif method === :lms
        any(<=(0), x) && return NaN
        fit = lms_fit(x)
        return lms_quantile(fit.μ, fit.σ, fit.λ, lower ? -1.96 : 1.96)
    else
        any(<=(0), x) && return NaN
        lx = log.(x)
        μ, σ = mean(lx), std(lx)
        return lower ? exp(μ - 1.96σ) : exp(μ + 1.96σ)
    end
end

"""
    assess_partitions(data; group, value)

Harris–Boyd style statistical partitioning evidence (Harris & Boyd 1990).
Does **not** recommend clinical partitions.
"""
function assess_partitions(data;
                           group,
                           value = :value)
    rows = _table_rows(data)
    labels = String[]
    vals = Float64[]
    for r in rows
        g = _rowget(r, group)
        v = _rowget(r, value)
        g === nothing && continue
        v isa Number && isfinite(Float64(v)) || continue
        push!(labels, string(g))
        push!(vals, Float64(v))
    end
    uniq = sort(unique(labels))
    length(uniq) < 2 &&
        return PartitionResult(uniq, 0.0, 1.0, :harris_boyd, false,
                               "Fewer than two groups with finite values.",
                               String[])
    gs = [vals[labels .== g] for g in uniq]
    if length(uniq) == 2
        z = _harris_boyd_z(gs[1], gs[2])
        # Critical value depends on SD ratio; use Harris–Boyd z* ≈ 3 as a conservative flag
        crit = _harris_boyd_critical(gs[1], gs[2])
        may = abs(z) > crit
        notes = "Harris–Boyd z=$(round(z; digits=3)) vs critical $(round(crit; digits=3)). \
                 This is statistical evidence only, not a partitioning recommendation."
        return PartitionResult(uniq, z, 2 * normal_sf(abs(z)), :harris_boyd, may, notes, [notes])
    else
        kw = kruskal_wallis(gs)
        notes = "More than two groups: Kruskal–Wallis H=$(round(kw.statistic; digits=3)), p=$(round(kw.pvalue; digits=4)). \
                 Statistical evidence only."
        return PartitionResult(uniq, kw.statistic, kw.pvalue, :kruskal_wallis,
                               kw.pvalue < 0.01, notes, [notes])
    end
end

function _harris_boyd_z(a, b)
    n1, n2 = length(a), length(b)
    s1, s2 = std(a), std(b)
    se = sqrt(s1^2 / n1 + s2^2 / n2)
    se == 0 && return 0.0
    (mean(a) - mean(b)) / se
end

function _harris_boyd_critical(a, b)
    r = std(a) / max(std(b), eps())
    r = max(r, 1 / r)
    # Harris & Boyd: larger SD ratio raises the critical z
    return 3.0 + 0.3 * (r - 1)
end

"""
    reference_curve(covariate, values; quantiles=(0.025, 0.50, 0.975), span=0.3, method=:quantile)

Continuous reference curves. `:quantile` uses locally weighted empirical
quantiles. `:lms` uses Cole LMS (global λ, local μ and σ) and back-transforms
the requested probabilities. Not a clinical reference system.
"""
function reference_curve(covariate::AbstractVector, values::AbstractVector;
                         quantiles = (0.025, 0.50, 0.975),
                         span::Float64 = 0.3,
                         method::Symbol = :quantile)
    xs = Float64[]
    ys = Float64[]
    for (c, v) in zip(covariate, values)
        if c isa Number && v isa Number && isfinite(Float64(c)) && isfinite(Float64(v))
            push!(xs, Float64(c))
            push!(ys, Float64(v))
        end
    end
    n = length(xs)
    n < 30 && throw(InsufficientDataError(30, n, "reference_curve"))
    perm = sortperm(xs)
    xs, ys = xs[perm], ys[perm]
    grid = collect(range(xs[1], xs[end]; length = min(50, n)))
    w = max(8, round(Int, span * n))
    cols = [Symbol("q", replace(string(q), "." => "_")) for q in quantiles]
    curves = Dict{Symbol, Vector{Float64}}()
    for c in cols
        curves[c] = Float64[]
    end
    λ = method === :lms ? boxcox_lambda(ys) : nothing
    for g in grid
        d = abs.(xs .- g)
        idx = partialsortperm(d, 1:min(w, n))
        local_y = ys[idx]
        if method === :lms
            pos = [v for v in local_y if v > 0]
            if length(pos) < 8
                for (q, c) in zip(quantiles, cols)
                    push!(curves[c], sample_quantile(local_y, q))
                end
            else
                μ = median(pos)
                if abs(λ) < 1e-8
                    σ = std(log.(pos ./ μ))
                else
                    σ = std(((pos ./ μ) .^ λ .- 1) ./ λ)
                end
                σ = σ > 0 && isfinite(σ) ? σ : 0.1
                for (q, c) in zip(quantiles, cols)
                    z = _norm_quantile(q)
                    push!(curves[c], lms_quantile(μ, σ, λ, z))
                end
            end
        else
            for (q, c) in zip(quantiles, cols)
                push!(curves[c], sample_quantile(local_y, q))
            end
        end
    end
    (; covariate = grid, quantiles = NamedTuple{Tuple(cols)}(Tuple(curves[c] for c in cols)),
     n, span, method, lambda = λ,
     notes = "Descriptive quantile curves. Not a clinical reference system.")
end

# Beasley–Springer–Moro style inverse normal for p in (0,1)
function _norm_quantile(p::Real)
    p = clamp(Float64(p), 1e-12, 1 - 1e-12)
    t = sqrt(-2 * log(p < 0.5 ? p : 1 - p))
    z = t - (2.515517 + 0.802853 * t + 0.010328 * t^2) /
        (1 + 1.432788 * t + 0.189269 * t^2 + 0.001308 * t^3)
    p < 0.5 ? -z : z
end
