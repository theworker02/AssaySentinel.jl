# Change-point subsystem. Automation remains explainable: :auto reports why.

"""
    detect_changes(data; method=:auto, timestamps=nothing, has_controls=false, rng)

Detect change points in a univariate series.

Methods:
- `:cusum` — Page (1954) two-sided CUSUM plus CUSUM-path localization
- `:likelihood` — Gaussian mean-change likelihood ratio / SIC scan
- `:pelt` — PELT for piecewise mean (Killick, Fearnhead & Eckley 2012)
- `:robust_median` — CUSUM on robustly standardized observations
- `:rolling` — rolling two-sample Welch tests
- `:bayesian` — Fearnhead (2006) product-partition posterior (multiple changes)
- `:turing` — hierarchical MCMC via the Turing.jl extension
- `:kernel` — energy-distance scan (Székely & Rizzo)
- `:auto` — choose from sample size, tail weight, missingness, cadence
"""
function detect_changes(data::AbstractVector;
                        method::Symbol = :auto,
                        timestamps = nothing,
                        sites = nothing,
                        model::Symbol = :single,
                        has_controls::Bool = false,
                        min_size::Int = 8,
                        rng::AbstractRNG = Random.default_rng())
    ts_all = timestamps === nothing ? nothing : collect(timestamps)
    vals = Float64[]
    tkeep = DateTime[]
    idxmap = Int[]
    sitekeep = String[]
    for (i, v) in enumerate(data)
        if v isa Number && isfinite(Float64(v))
            push!(vals, Float64(v))
            push!(idxmap, i)
            if ts_all !== nothing && i <= length(ts_all) && ts_all[i] !== nothing &&
               !(ts_all[i] isa Missing)
                push!(tkeep, DateTime(ts_all[i]))
            end
            if sites !== nothing && i <= length(sites) && sites[i] !== nothing
                push!(sitekeep, string(sites[i]))
            end
        end
    end
    n = length(vals)
    reason = ""
    chosen = method
    if method === :auto
        chosen, reason = select_change_method(vals, data; has_controls, timestamps = tkeep)
    else
        reason = "User-selected method :$method."
    end

    if n < min_size
        return ChangePointResult(false, Int[], DateTime[], 0.0, chosen, reason, 0.0,
                                 ["Fewer than $min_size finite observations; change-point scan skipped."],
                                 (; n, missing_fraction = missing_fraction(data)))
    end

    raw = if chosen === :cusum
        _cp_cusum(vals)
    elseif chosen === :likelihood
        _cp_likelihood(vals)
    elseif chosen === :pelt
        _cp_pelt(vals; min_size)
    elseif chosen === :robust_median
        _cp_robust(vals)
    elseif chosen === :rolling
        _cp_rolling(vals)
    elseif chosen === :bayesian
        _cp_bayesian(vals)
    elseif chosen === :turing
        _cp_turing(vals; rng, sites = isempty(sitekeep) ? nothing : sitekeep, model)
    elseif chosen === :kernel
        _cp_kernel(vals)
    else
        throw(ArgumentError("Unknown change-point method :$chosen"))
    end

    orig_idx = [idxmap[i] for i in raw.indices]
    times = DateTime[]
    if ts_all !== nothing
        for i in orig_idx
            if i <= length(ts_all) && ts_all[i] !== nothing && !(ts_all[i] isa Missing)
                push!(times, DateTime(ts_all[i]))
            end
        end
    end
    ChangePointResult(
        raw.detected,
        orig_idx,
        times,
        raw.statistic,
        chosen,
        reason,
        raw.confidence,
        raw.evidence,
        merge(raw.details, (; n, missing_fraction = missing_fraction(data), rng_used = false)),
    )
end

function select_change_method(vals::Vector{Float64}, raw;
                              has_controls::Bool,
                              timestamps)
    n = length(vals)
    miss = missing_fraction(raw)
    heavy = excess_kurtosis(vals) > 2.5 || (robust_mad(vals) > 0 && std(vals) / robust_mad(vals) > 1.6)
    regular = timestamps isa AbstractVector{DateTime} && is_regular_cadence(timestamps)
    alarms = _cusum_alarm_count(vals)
    if n < 20
        return :robust_median, "n=$n < 20: robust median CUSUM preferred for small samples."
    elseif miss > 0.15 || !regular && n < 80
        return :robust_median, "Missingness=$(round(miss; digits=2)) or irregular cadence: robust method."
    elseif heavy
        return :robust_median, "Heavy tails (excess kurtosis or SD/MAD ratio): robust median CUSUM."
    elseif n >= 80 && alarms >= 2
        return :pelt, "CUSUM crossed the decision interval $alarms times: PELT for multiple mean segments."
    elseif has_controls && n < 400
        return :likelihood, "Control-like series with moderate n: Gaussian likelihood scan."
    elseif 80 <= n < 400 && regular
        return :bayesian, "Moderate regular series (n=$n): Fearnhead product-partition posterior."
    elseif n >= 400
        return :pelt, "n=$n ≥ 400: PELT piecewise-mean segmentation."
    else
        return :cusum, "Default CUSUM (Page 1954) for moderate, approximately regular series."
    end
end

function _cusum_alarm_count(x::Vector{Float64}; k::Float64 = 0.5, h::Float64 = 5.0)
    z, _, _ = standardize(x)
    Sp = 0.0
    Sm = 0.0
    n = 0
    @inbounds for zi in z
        Sp = max(0.0, Sp + zi - k)
        Sm = max(0.0, Sm - zi - k)
        if Sp > h || Sm > h
            n += 1
            Sp = 0.0
            Sm = 0.0
        end
    end
    n
end

function _cp_cusum(x::Vector{Float64}; k::Float64 = 0.5, h::Float64 = 5.0)
    z, μ, σ = standardize(x)
    Sp = 0.0
    Sm = 0.0
    alarms = Int[]
    @inbounds for i in eachindex(z)
        Sp = max(0.0, Sp + z[i] - k)
        Sm = max(0.0, Sm - z[i] - k)
        if Sp > h || Sm > h
            push!(alarms, i)
            Sp = 0.0
            Sm = 0.0
        end
    end
    S = cumsum(x .- mean(x))
    τ = argmax(abs.(S))
    stat = maximum(abs.(S))
    detected = !isempty(alarms) || stat > 2 * std(S)
    ev = String[]
    detected && push!(ev, "CUSUM localized a mean-level transition near observation $τ.")
    !isempty(alarms) && push!(ev, "Sequential CUSUM crossed h=$h at $(length(alarms)) location(s).")
    (
        detected = detected,
        indices = detected ? unique!(sort!(vcat(alarms, [τ]))) : Int[],
        statistic = stat,
        confidence = detected ? min(0.99, 0.55 + 0.08 * length(alarms) + 0.1 * (stat / (std(S) + eps()))) : 0.2,
        evidence = ev,
        details = (; k, h, path_peak = τ),
    )
end

function _cp_likelihood(x::Vector{Float64})
    n = length(x)
    ss_full = sum(abs2, x .- mean(x))
    ss_full <= 0 && return (detected = false, indices = Int[], statistic = 0.0,
                            confidence = 0.0, evidence = String["Zero variance."],
                            details = (;))
    best_lr = -Inf
    best_τ = 1
    @inbounds for τ in 2:(n - 2)
        μ1 = mean(view(x, 1:τ))
        μ2 = mean(view(x, (τ + 1):n))
        ss = sum(abs2, view(x, 1:τ) .- μ1) + sum(abs2, view(x, (τ + 1):n) .- μ2)
        ss <= 0 && continue
        lr = (n / 2) * log(ss_full / ss)
        if lr > best_lr
            best_lr = lr
            best_τ = τ
        end
    end
    # SIC penalty: log(n)
    detected = best_lr > log(n) + 1.5
    ev = detected ?
         ["Likelihood-ratio mean-change scan peaked at observation $best_τ (LR=$(round(best_lr; digits=2)))."] :
         String["No mean-change LR exceeded the SIC penalty."]
    (
        detected = detected,
        indices = detected ? [best_τ] : Int[],
        statistic = best_lr,
        confidence = detected ? min(0.99, 1 - exp(-max(best_lr - log(n), 0) / 4)) : 0.15,
        evidence = ev,
        details = (; penalty = log(n), peak = best_τ),
    )
end

"""
PELT for piecewise constant mean with L2 cost (Killick et al., JASA 2012).

The series is standardized so the SIC/MBIC penalty is scale-free. Pruning
uses the paper's inequality only — `min_size` constrains candidate costs,
not membership of the surviving set `R` (the previous implementation
dropped every new candidate on the next step).
"""
function _cp_pelt(x::Vector{Float64}; min_size::Int = 8, β = nothing)
    n = length(x)
    z, _, σ = standardize(x)
    σ = σ == 0 || !isfinite(σ) ? 1.0 : σ
    # MBIC for a mean-only segment (p = 1): (1 + 2p) log n = 3 log n
    pen = β === nothing ? 3 * log(n) : Float64(β)
    css = cumsum(z)
    css2 = cumsum(abs2.(z))
    function cost(a, b)
        s = css[b] - (a > 1 ? css[a - 1] : 0.0)
        q = css2[b] - (a > 1 ? css2[a - 1] : 0.0)
        m = b - a + 1
        return q - s^2 / m
    end
    F = fill(Inf, n + 1)
    F[1] = -pen
    cps = [Int[] for _ in 1:(n + 1)]
    R = [0]
    for τ in 1:n
        best = Inf
        best_s = 0
        for s in R
            if s == 0 || τ - s >= min_size
                c = F[s + 1] + cost(s + 1, τ) + pen
                if c < best
                    best = c
                    best_s = s
                end
            end
        end
        if !isfinite(best)
            best = F[1] + cost(1, τ) + pen
            best_s = 0
        end
        F[τ + 1] = best
        cps[τ + 1] = best_s == 0 ? Int[] : vcat(cps[best_s + 1], best_s)
        # Killick et al.: keep s if F(s) + C(s+1,τ) + K ≤ F(τ), K = 0 for RSS
        Rnew = Int[]
        for s in R
            if F[s + 1] + cost(s + 1, τ) <= F[τ + 1]
                push!(Rnew, s)
            end
        end
        push!(Rnew, τ)
        R = Rnew
    end
    changepoints = filter(c -> 0 < c < n, cps[n + 1])
    detected = !isempty(changepoints)
    ev = detected ?
         ["PELT reported $(length(changepoints)) mean-level change(s) with MBIC penalty $(round(pen; digits=2))."] :
         String["PELT found no change under the MBIC penalty 3 log n."]
    (
        detected = detected,
        indices = changepoints,
        statistic = -F[n + 1],
        confidence = detected ? min(0.95, 0.6 + 0.1 * length(changepoints)) : 0.2,
        evidence = ev,
        details = (; penalty = pen, min_size, standardized = true),
    )
end

function _cp_robust(x::Vector{Float64})
    z, _, _ = standardize(x; robust = true)
    raw = _cp_cusum(z; k = 0.4, h = 4.5)
    ev = ["Robust median/MAD standardization preceded CUSUM."]
    append!(ev, raw.evidence)
    merge(raw, (evidence = ev, details = merge(raw.details, (; robust = true))))
end

function _cp_rolling(x::Vector{Float64}; window::Int = 0)
    n = length(x)
    w = window <= 0 ? max(8, n ÷ 8) : window
    best_p = 1.0
    best_i = w
    best_t = 0.0
    for i in w:(n - w)
        left = view(x, (i - w + 1):i)
        right = view(x, (i + 1):(i + w))
        r = welch_t(left, right)
        if r.pvalue < best_p
            best_p = r.pvalue
            best_i = i
            best_t = r.statistic
        end
    end
    detected = best_p < 0.01
    ev = detected ?
         ["Rolling Welch test minimum p=$(round(best_p; digits=4)) at observation $best_i."] :
         String["Rolling Welch tests did not meet p < 0.01."]
    (
        detected = detected,
        indices = detected ? [best_i] : Int[],
        statistic = abs(best_t),
        confidence = detected ? 1 - best_p : 0.2,
        evidence = ev,
        details = (; window = w, min_p = best_p),
    )
end

_logaddexp(a::Float64, b::Float64) = a == -Inf ? b : b == -Inf ? a :
    (a > b ? a + log1p(exp(b - a)) : b + log1p(exp(a - b)))

function _log_seg_gaussian(css, css2, a::Int, b::Int, σ2::Float64, μ0::Float64, κ0::Float64)
    m = b - a + 1
    s = css[b] - (a > 1 ? css[a - 1] : 0.0)
    q = css2[b] - (a > 1 ? css2[a - 1] : 0.0)
    μhat = s / m
    rss = max(q - s^2 / m, 0.0)
    κn = κ0 + m
    return -0.5 * m * log(2π * σ2) - 0.5 * log(κn / κ0) -
           (rss + (κ0 * m / κn) * (μhat - μ0)^2) / (2σ2)
end

"""
Fearnhead (2006) exact product-partition inference for multiple mean changes.

Geometric hazard prior on changepoints; Gaussian observations with known
variance (sample variance) and a weak conjugate prior on the segment mean.
Returns MAP locations and the smoothed posterior mass at each index.
"""
function _cp_bayesian(x::Vector{Float64}; min_size::Int = 8, p::Union{Nothing, Float64} = nothing)
    n = length(x)
    σ2 = var(x)
    σ2 <= 0 && return (detected = false, indices = Int[], statistic = 0.0,
                       confidence = 0.0, evidence = String["Zero variance."], details = (;))
    μ0 = mean(x)
    κ0 = 0.01
    hazard = p === nothing ? min(0.2, max(1 / sqrt(n), 2 / n)) : Float64(p)
    logp = log(hazard)
    logq = Base.log1p(-hazard)
    css = cumsum(x)
    css2 = cumsum(abs2.(x))
    logf(a, b) = _log_seg_gaussian(css, css2, a, b, σ2, μ0, κ0)

    # Forward: F[t] = log P(data_1:t, changepoint at t) with F[0] = start
    # A[t] = log P(data_1:t)
    A = fill(-Inf, n + 1)
    F = fill(-Inf, n + 1)  # mass of paths with a changepoint at t (t=0 is origin)
    A[1] = 0.0
    F[1] = 0.0
    parent = zeros(Int, n)
    for t in 1:n
        acc = -Inf
        best = -Inf
        best_s = 0
        for s in 0:(t - 1)
            seglen = t - s
            if seglen < min_size && !(s == 0 && t < min_size)
                continue
            end
            lp_trans = (s == 0 ? 0.0 : logp) + max(seglen - 1, 0) * logq
            lp = F[s + 1] + lp_trans + logf(s + 1, t)
            acc = _logaddexp(acc, lp)
            if lp > best
                best = lp
                best_s = s
            end
        end
        A[t + 1] = acc
        F[t + 1] = acc
        parent[t] = best_s
    end

    # Backward: B[t] = log P(data_t:n | a new segment starts at t)
    B = fill(-Inf, n + 2)
    B[n + 1] = 0.0
    for t in n:-1:1
        acc = -Inf
        for u in (t + 1):(n + 1)
            seglen = u - t
            if seglen < min_size && !(u == n + 1 && seglen < min_size)
                u < n + 1 && continue
            end
            lp_trans = (u == n + 1 ? 0.0 : logp) + max(seglen - 1, 0) * logq
            acc = _logaddexp(acc, logf(t, u - 1) + lp_trans + B[u])
        end
        B[t] = acc
    end

    post = zeros(n)
    logZ = A[n + 1]
    if isfinite(logZ)
        for τ in min_size:(n - min_size)
            # changepoint at τ: left segment ends at τ, right starts at τ+1
            lp = F[τ + 1] + logp + B[τ + 1] - logZ
            post[τ] = isfinite(lp) ? exp(min(lp, 0.0)) : 0.0
        end
        s = sum(post)
        s > 0 && (post ./= s)
    end

    # MAP path
    map_cps = Int[]
    t = n
    while t > 0
        s = parent[t]
        s > 0 && push!(map_cps, s)
        t = s
    end
    reverse!(map_cps)
    filter!(c -> 0 < c < n, map_cps)

    # Posterior peaks (non-maximum suppression)
    peaks = Int[]
    for i in 2:(n - 1)
        post[i] >= post[i - 1] && post[i] >= post[i + 1] && post[i] >= 0.08 && push!(peaks, i)
    end
    kept = Int[]
    for i in peaks
        if isempty(kept) || i - kept[end] >= min_size
            push!(kept, i)
        elseif post[i] > post[kept[end]]
            kept[end] = i
        end
    end
    indices = !isempty(map_cps) ? map_cps : kept
    mode = isempty(post) ? 1 : argmax(post)
    conf = post[mode]
    detected = !isempty(indices) && conf >= 0.08
    ev = if detected
        ["Fearnhead product-partition posterior mode at $mode (P=$(round(conf; digits=3))); MAP changes at $(join(indices, ", "))."]
    else
        String["Bayesian product-partition posterior did not concentrate on a change."]
    end
    (
        detected = detected,
        indices = detected ? indices : Int[],
        statistic = conf,
        confidence = conf,
        evidence = ev,
        details = (; posterior_mode = mode, posterior_mass = conf,
                     posterior = post, hazard, map_indices = map_cps),
    )
end

"""
    _cp_turing(x; rng)

Hierarchical MCMC changepoint. Implemented by `AssaySentinelTuringExt`
when Turing.jl is loaded; otherwise raises a clear load error.
"""
function _cp_turing(x::Vector{Float64}; rng::AbstractRNG = Random.default_rng(),
                    sites = nothing, model::Symbol = :single, kwargs...)
    throw(ArgumentError("detect_changes(...; method=:turing) requires Turing.jl. Add Turing and run `using Turing`."))
end

function _cp_kernel(x::Vector{Float64})
    n = length(x)
    best = -Inf
    best_τ = 1
    step = max(1, n ÷ 80)
    for τ in 10:step:(n - 10)
        d = energy_distance(view(x, 1:τ), view(x, (τ + 1):n))
        if d > best
            best = d
            best_τ = τ
        end
    end
    # Null scale: energy distance of a random split
    mid = n ÷ 2
    null = energy_distance(view(x, 1:mid), view(x, (mid + 1):n))
    detected = best > 1.8 * max(null, eps()) && best > 0
    ev = detected ?
         ["Energy-distance scan peaked at observation $best_τ (D=$(round(best; digits=4)))."] :
         String["Energy-distance scan did not exceed the mid-split reference."]
    (
        detected = detected,
        indices = detected ? [best_τ] : Int[],
        statistic = best,
        confidence = detected ? min(0.9, 0.5 + best / (best + null + 1)) : 0.2,
        evidence = ev,
        details = (; peak = best_τ, energy = best),
    )
end
