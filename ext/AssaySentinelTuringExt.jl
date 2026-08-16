module AssaySentinelTuringExt

using AssaySentinel
using Random
using Statistics
using Turing

"""
Single-cut hierarchical Gaussian changepoint.
"""
@model function _assay_changepoint(x, μ0, σ0)
    n = length(x)
    τ ~ DiscreteUniform(2, n - 1)
    μ1 ~ Normal(μ0, 2 * σ0 + 0.1)
    μ2 ~ Normal(μ0, 2 * σ0 + 0.1)
    σ ~ truncated(Normal(σ0, σ0 + 0.1), 1e-6, Inf)
    for i in 1:n
        x[i] ~ Normal(i <= τ ? μ1 : μ2, σ)
    end
end

"""
Two-cut model: three piecewise means, unordered discrete cuts (then sorted).
"""
@model function _assay_two_changepoint(x, μ0, σ0)
    n = length(x)
    u1 ~ DiscreteUniform(2, n - 2)
    u2 ~ DiscreteUniform(2, n - 2)
    μ1 ~ Normal(μ0, 2 * σ0 + 0.1)
    μ2 ~ Normal(μ0, 2 * σ0 + 0.1)
    μ3 ~ Normal(μ0, 2 * σ0 + 0.1)
    σ ~ truncated(Normal(σ0, σ0 + 0.1), 1e-6, Inf)
    a = min(u1, u2)
    b = max(u1, u2)
    if b == a
        b = min(n - 1, a + 1)
    end
    for i in 1:n
        m = i <= a ? μ1 : (i <= b ? μ2 : μ3)
        x[i] ~ Normal(m, σ)
    end
end

"""
Site intercepts α_s ~ N(0, τ), shared residual σ, optional shared mean shift after τ.
"""
@model function _assay_hierarchical_sites(y, sid, nsites, μ0, σ0)
    n = length(y)
    μ ~ Normal(μ0, 2 * σ0 + 0.1)
    τ ~ truncated(Normal(0, σ0 + 0.1), 1e-6, Inf)
    σ ~ truncated(Normal(σ0, σ0 + 0.1), 1e-6, Inf)
    δ ~ Normal(0, 2 * σ0 + 0.1)
    cut ~ DiscreteUniform(2, n - 1)
    α = Vector{Float64}(undef, nsites)
    for s in 1:nsites
        α[s] ~ Normal(0, τ)
    end
    for i in 1:n
        y[i] ~ Normal(μ + α[sid[i]] + (i > cut ? δ : 0.0), σ)
    end
end

function _mh(model, samples, rng)
    Turing.sample(model, Turing.MH(), samples; progress = false, rng)
end

function AssaySentinel._cp_turing(x::Vector{Float64};
    rng::AbstractRNG = Random.default_rng(),
    sites = nothing,
    model::Symbol = :single,
    samples::Int = 400,
    kwargs...)
    n = length(x)
    n < 8 && return (detected = false, indices = Int[], statistic = 0.0,
        confidence = 0.0,
        evidence = String["Too few observations for Turing changepoint."],
        details = (;))
    μ0 = mean(x)
    σ0 = std(x)
    σ0 = σ0 > 0 && isfinite(σ0) ? σ0 : 1.0
    if model === :hierarchical && sites !== nothing && length(unique(sites)) >= 2
        return _turing_from_hierarchical(x, sites, μ0, σ0, samples, rng)
    elseif model === :multiple || model === :two
        chn = _mh(_assay_two_changepoint(x, μ0, σ0), samples, rng)
        a = Int.(vec(Array(chn[:u1])))
        b = Int.(vec(Array(chn[:u2])))
        cuts = [minmax(a[i], b[i]) for i in eachindex(a)]
        left = [c[1] for c in cuts]
        right = [c[2] for c in cuts]
        mode1 = _mode_int(left, n)
        mode2 = _mode_int(right, n)
        indices = unique(filter(i -> 1 < i < n, [mode1, mode2]))
        conf = max(_mass_at(left, mode1), _mass_at(right, mode2))
        ev = [
            "Turing two-cut MH modes at $(join(indices, ", ")) (P=$(round(conf; digits=3))).",
        ]
        return (detected = !isempty(indices) && conf >= 0.06, indices,
            statistic = conf, confidence = conf, evidence = ev,
            details = (; model = :multiple, samples, sampler = :mh,
                interval_90_first = _q90(left),
                interval_90_second = _q90(right)))
    end
    chn = _mh(_assay_changepoint(x, μ0, σ0), samples, rng)
    τs = Int.(vec(Array(chn[:τ])))
    post = zeros(n)
    for t in τs
        1 <= t <= n && (post[t] += 1)
    end
    post ./= length(τs)
    mode = argmax(post)
    conf = post[mode]
    qs = _q90(τs)
    detected = conf >= 0.08
    ev = [
        "Turing MH posterior mode at $mode (P=$(round(conf; digits=3)); 90% interval $(qs[1])–$(qs[3])).",
    ]
    (
        detected = detected,
        indices = detected ? [mode] : Int[],
        statistic = conf,
        confidence = conf,
        evidence = ev,
        details = (; posterior_mode = mode, posterior_mass = conf,
            interval_90 = qs, samples, sampler = :mh, model = :single),
    )
end

function AssaySentinel._turing_hierarchical_sites(vals, labs, ts, uniq; rng,
    samples::Int = 400)
    μ0 = mean(vals)
    σ0 = std(vals)
    σ0 = σ0 > 0 && isfinite(σ0) ? σ0 : 1.0
    sid = [findfirst(==(s), uniq) for s in labs]
    chn = _mh(_assay_hierarchical_sites(vals, sid, length(uniq), μ0, σ0), samples, rng)
    cuts = Int.(vec(Array(chn[:cut])))
    δs = vec(Array(chn[:δ]))
    μs = vec(Array(chn[:μ]))
    τs = vec(Array(chn[:τ]))
    mode = _mode_int(cuts, length(vals))
    conf = _mass_at(cuts, mode)
    global_d = AssaySentinel.DriftResult(;
        detected = abs(mean(δs)) > 0.15 * σ0,
        probability = conf,
        magnitude = abs(mean(δs)) / (abs(mean(μs)) + eps()),
        direction = mean(δs) >= 0 ? :increase : :decrease,
        start_index = mode,
        detector = :turing,
        kind = :hierarchical,
        evidence = [
            "Turing hierarchical site model: shared cut mode $mode, E[δ]=$(round(mean(δs); digits=3)).",
        ],
        details = (; interval_90 = _q90(cuts), tau = mean(τs), samples),
    )
    # Reuse EB location shrinkage for site table; attach global Turing drift
    eb = AssaySentinel.hierarchical_sites(vals, labs; timestamps = ts, method = :eb, rng)
    AssaySentinel.HierarchicalSiteResult(
        eb.sites, mean(μs), mean(τs), eb.within_sd, global_d,
        eb.heterogeneity_q, eb.heterogeneity_p,
        global_d.detected ? :global : eb.attribution, eb.concordance,
        eb.i2, eb.prediction_lo, eb.prediction_hi,
        vcat(global_d.evidence, eb.evidence),
        eb.notes,
        (;
            method = :turing,
            samples,
            schema_version = string(AssaySentinel.SCHEMA_VERSION),
        ),
    )
end

function _turing_from_hierarchical(x, sites, μ0, σ0, samples, rng)
    uniq = sort(unique(sites))
    sid = [findfirst(==(s), uniq) for s in sites]
    chn = _mh(_assay_hierarchical_sites(x, sid, length(uniq), μ0, σ0), samples, rng)
    cuts = Int.(vec(Array(chn[:cut])))
    mode = _mode_int(cuts, length(x))
    conf = _mass_at(cuts, mode)
    ev = [
        "Turing hierarchical-site MH cut mode at $mode (P=$(round(conf; digits=3)); k=$(length(uniq)) sites).",
    ]
    (detected = conf >= 0.08, indices = [mode], statistic = conf, confidence = conf,
        evidence = ev,
        details = (; model = :hierarchical, samples, n_sites = length(uniq),
            interval_90 = _q90(cuts)))
end

_mode_int(xs, n) = begin
    c = zeros(Int, n)
    for t in xs
        1 <= t <= n && (c[t] += 1)
    end
    argmax(c)
end

_mass_at(xs, mode) = count(==(mode), xs) / max(length(xs), 1)

function _q90(xs)
    isempty(xs) && return (NaN, NaN, NaN)
    (quantile(xs, 0.05), quantile(xs, 0.50), quantile(xs, 0.95))
end

end
