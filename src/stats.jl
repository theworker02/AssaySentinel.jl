# Shared statistical primitives. Methods cite classical references in
# STATISTICAL_METHODS.md. Missing and NaN are dropped, never zero-filled.

const _MISSING_KINDS = (Missing, Nothing)

function is_invalid_obs(x)
    x === nothing && return true
    x isa Missing && return true
    x isa Number && return !isfinite(Float64(x))
    return true
end

is_invalid_obs(x::Real) = !isfinite(Float64(x))

"""
    valid_values(x) -> Vector{Float64}

Return finite numeric observations. Missing and NaN are omitted, not replaced.
"""
function valid_values(x::AbstractVector)
    out = Float64[]
    sizehint!(out, length(x))
    for v in x
        if v isa Number && isfinite(Float64(v))
            push!(out, Float64(v))
        end
    end
    return out
end

function valid_pairs(times::AbstractVector, values::AbstractVector)
    length(times) == length(values) ||
        throw(ArgumentError("times and values must have the same length"))
    ts = DateTime[]
    vs = Float64[]
    sizehint!(ts, length(values))
    sizehint!(vs, length(values))
    for i in eachindex(values)
        v = values[i]
        t = times[i]
        if v isa Number && isfinite(Float64(v)) && t !== nothing && !(t isa Missing)
            push!(ts, DateTime(t))
            push!(vs, Float64(v))
        end
    end
    return ts, vs
end

function require_n(v::AbstractVector, n::Int, context::AbstractString)
    length(v) < n && throw(InsufficientDataError(n, length(v), context))
    v
end

"""
    robust_mad(x)

Normalized MAD: `1.4826 * median(|x − median(x)|)` (Rousseeuw & Croux 1993).
"""
function robust_mad(x::AbstractVector{<:Real})
    isempty(x) && return NaN
    med = median(x)
    return 1.4826 * median(abs.(x .- med))
end

function standardize(x::AbstractVector{<:Real}; robust::Bool = false)
    if robust
        loc = median(x)
        scl = robust_mad(x)
    else
        loc = mean(x)
        scl = std(x)
    end
    scl = scl == 0 || !isfinite(scl) ? 1.0 : scl
    return (x .- loc) ./ scl, loc, scl
end

"""
    theil_sen(x, y)

Theil–Sen robust slope and intercept (Theil 1950; Sen 1968).
Intercept is the median of `y − slope * x`.
"""
function theil_sen(x::AbstractVector{<:Real}, y::AbstractVector{<:Real})
    n = length(x)
    n == length(y) || throw(ArgumentError("x and y length mismatch"))
    n < 2 && throw(InsufficientDataError(2, n, "Theil–Sen regression"))
    slopes = Float64[]
    sizehint!(slopes, n * (n - 1) ÷ 2)
    @inbounds for i in 1:(n - 1)
        for j in (i + 1):n
            dx = x[j] - x[i]
            if dx != 0
                push!(slopes, (y[j] - y[i]) / dx)
            end
        end
    end
    isempty(slopes) && return (slope = 0.0, intercept = median(y))
    slope = median(slopes)
    intercept = median(y .- slope .* x)
    return (slope = slope, intercept = intercept)
end

"""
    welch_t(a, b)

Welch two-sample t statistic and two-sided p-value using a regularized
incomplete-beta approximation to the t tail.
"""
function welch_t(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    n1, n2 = length(a), length(b)
    (n1 < 2 || n2 < 2) && return (statistic = 0.0, pvalue = 1.0, df = 1.0)
    m1, m2 = mean(a), mean(b)
    v1, v2 = var(a), var(b)
    se2 = v1 / n1 + v2 / n2
    se2 <= 0 && return (statistic = 0.0, pvalue = 1.0, df = Float64(n1 + n2 - 2))
    t = (m1 - m2) / sqrt(se2)
    df = se2^2 / ((v1 / n1)^2 / (n1 - 1) + (v2 / n2)^2 / (n2 - 1))
    p = 2 * t_sf(abs(t), df)
    return (statistic = t, pvalue = p, df = df)
end

"""
    t_sf(t, df)

Survival function P(|T| > t)/2 for a one-sided tail, i.e. P(T > t).
"""
function t_sf(t::Real, df::Real)
    df <= 0 && return 1.0
    x = df / (df + t^2)
    return 0.5 * beta_inc_reg(df / 2, 0.5, x)
end

# Regularized incomplete beta I_x(a,b) via continued fraction (Numerical Recipes).
function beta_inc_reg(a::Real, b::Real, x::Real)
    x <= 0 && return 0.0
    x >= 1 && return 1.0
    lbeta = loggamma(a) + loggamma(b) - loggamma(a + b)
    front = exp(log(x) * a + log(1 - x) * b - lbeta) / a
    if x < (a + 1) / (a + b + 2)
        return front * beta_cf(a, b, x)
    else
        return 1 - (front * (a / b) * ((1 - x) / x) * beta_cf(b, a, 1 - x))
    end
end

function beta_cf(a::Real, b::Real, x::Real; maxiter = 200, eps = 1e-12)
    am = bm = qab = a + b
    qap = a + 1
    qam = a - 1
    c = 1.0
    d = 1 - qab * x / qap
    d = abs(d) < 1e-30 ? 1e-30 : d
    d = 1 / d
    h = d
    for m in 1:maxiter
        m2 = 2m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1 + aa * d
        d = abs(d) < 1e-30 ? 1e-30 : d
        c = 1 + aa / c
        c = abs(c) < 1e-30 ? 1e-30 : c
        d = 1 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1 + aa * d
        d = abs(d) < 1e-30 ? 1e-30 : d
        c = 1 + aa / c
        c = abs(c) < 1e-30 ? 1e-30 : c
        d = 1 / d
        delta = d * c
        h *= delta
        abs(delta - 1) < eps && break
    end
    return h
end

function loggamma(z::Real)
    # Lanczos approximation
    z < 0.5 && return log(π / sin(π * z)) - loggamma(1 - z)
    g = 7
    p = (
        0.99999999999980993,
        676.5203681218851,
        -1259.1392167224028,
        771.32342877765313,
        -176.61502916214059,
        12.507343278686905,
        -0.13857109526572012,
        9.9843695780195716e-6,
        1.5056327351493116e-7,
    )
    x = p[1]
    for i in 2:length(p)
        x += p[i] / (z + i - 2)
    end
    t = z + g - 0.5
    return 0.5 * log(2π) + (z - 0.5) * log(t) - t + log(x)
end

"""
    mann_whitney(a, b)

Mann–Whitney U statistic and normal-approximation two-sided p-value
(Mann & Whitney 1947).
"""
function mann_whitney(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    n1, n2 = length(a), length(b)
    (n1 == 0 || n2 == 0) && return (statistic = 0.0, pvalue = 1.0)
    ranks = tied_ranks(vcat(a, b))
    r1 = sum(view(ranks, 1:n1))
    u = r1 - n1 * (n1 + 1) / 2
    mu = n1 * n2 / 2
    sigma = sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
    sigma == 0 && return (statistic = u, pvalue = 1.0)
    z = (u - mu) / sigma
    p = 2 * normal_sf(abs(z))
    return (statistic = u, pvalue = min(1.0, p))
end

function tied_ranks(x::AbstractVector{<:Real})
    n = length(x)
    idx = sortperm(x)
    ranks = similar(x, Float64)
    i = 1
    while i <= n
        j = i
        while j < n && x[idx[j + 1]] == x[idx[i]]
            j += 1
        end
        avg = (i + j) / 2
        for k in i:j
            ranks[idx[k]] = avg
        end
        i = j + 1
    end
    return ranks
end

function _erfc(x::Real)
    z = abs(Float64(x))
    t = 1 / (1 + 0.3275911 * z)
    a1, a2, a3, a4, a5 = 0.254829592, -0.284496736, 1.421413741, -1.453152027, 1.061405429
    y = t * (a1 + t * (a2 + t * (a3 + t * (a4 + t * a5)))) * exp(-z * z)
    return x >= 0 ? y : 2 - y
end

normal_sf(z::Real) = 0.5 * _erfc(z / sqrt(2))

"""
    kruskal_wallis(groups)

Kruskal–Wallis H statistic (Kruskal & Wallis 1952) and chi-squared p-value.
"""
function kruskal_wallis(groups::Vector{Vector{Float64}})
    groups = filter(!isempty, groups)
    k = length(groups)
    k < 2 && return (statistic = 0.0, pvalue = 1.0, df = 0)
    allv = reduce(vcat, groups)
    n = length(allv)
    ranks = tied_ranks(allv)
    h = 0.0
    offset = 0
    for g in groups
        ni = length(g)
        rbar = mean(view(ranks, (offset + 1):(offset + ni)))
        h += ni * (rbar - (n + 1) / 2)^2
        offset += ni
    end
    h = 12 / (n * (n + 1)) * h
    df = k - 1
    p = chisq_sf(h, df)
    return (statistic = h, pvalue = p, df = df)
end

function chisq_sf(x::Real, k::Real)
    x <= 0 && return 1.0
    k <= 0 && return 1.0
    # P(χ²_k > x) = 1 - P(Γ(k/2, 1/2) ≤ x) ≈ regularized gamma
    return gamma_sf(k / 2, x / 2)
end

function gamma_sf(s::Real, x::Real)
    # upper regularized gamma Q(s,x) via series / continued fraction
    x <= 0 && return 1.0
    if x < s + 1
        return 1 - gamma_lower_series(s, x)
    else
        return gamma_cf(s, x)
    end
end

function gamma_lower_series(s::Real, x::Real; maxiter = 200)
    term = 1 / s
    tot = term
    for n in 1:maxiter
        term *= x / (s + n)
        tot += term
        abs(term) < abs(tot) * 1e-12 && break
    end
    return tot * exp(-x + s * log(x) - loggamma(s))
end

function gamma_cf(s::Real, x::Real; maxiter = 200)
    b0 = x + 1 - s
    c = 1e30
    d = 1 / b0
    h = d
    for i in 1:maxiter
        an = -i * (i - s)
        b = b0 + 2i
        d = an * d + b
        d = abs(d) < 1e-30 ? 1e-30 : d
        c = b + an / c
        c = abs(c) < 1e-30 ? 1e-30 : c
        d = 1 / d
        delta = d * c
        h *= delta
        abs(delta - 1) < 1e-12 && break
    end
    return h * exp(-x + s * log(x) - loggamma(s))
end

"""
    levene_bf(groups)

Brown–Forsythe robust variance test (Brown & Forsythe 1974): ANOVA on
`|x − median_g|`.
"""
function levene_bf(groups::Vector{Vector{Float64}})
    groups = filter(g -> length(g) >= 2, groups)
    k = length(groups)
    k < 2 && return (statistic = 0.0, pvalue = 1.0)
    zs = [abs.(g .- median(g)) for g in groups]
    return oneway_anova(zs)
end

function oneway_anova(groups::Vector{Vector{Float64}})
    groups = filter(!isempty, groups)
    k = length(groups)
    k < 2 && return (statistic = 0.0, pvalue = 1.0)
    allv = reduce(vcat, groups)
    n = length(allv)
    gm = mean(allv)
    ssb = sum(length(g) * (mean(g) - gm)^2 for g in groups)
    ssw = sum(sum((x - mean(g))^2 for x in g) for g in groups)
    dfb, dfw = k - 1, n - k
    dfw <= 0 && return (statistic = 0.0, pvalue = 1.0)
    f = (ssb / dfb) / (ssw / dfw)
    # F tail via beta
    x = dfw / (dfw + dfb * f)
    p = beta_inc_reg(dfw / 2, dfb / 2, x)
    return (statistic = f, pvalue = p)
end

"""
    ks_statistic(a, b)

Two-sample Kolmogorov–Smirnov D (Kolmogorov 1933; Smirnov 1948).
"""
function ks_statistic(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    sa, sb = sort(a), sort(b)
    n, m = length(sa), length(sb)
    (n == 0 || m == 0) && return 0.0
    i = j = 1
    d = 0.0
    fa = fb = 0.0
    while i <= n || j <= m
        take_a = j > m || (i <= n && sa[i] <= sb[j])
        take_b = i > n || (j <= m && sb[j] <= sa[i])
        if take_a
            fa = i / n
            i += 1
        end
        if take_b
            fb = j / m
            j += 1
        end
        d = max(d, abs(fa - fb))
    end
    return d
end

function ks_pvalue(d::Real, n::Int, m::Int)
    neff = n * m / (n + m)
    # Asymptotic approximation (Stephens)
    lam = (sqrt(neff) + 0.12 + 0.11 / sqrt(neff)) * d
    p = 0.0
    for k in 1:20
        p += 2 * (-1)^(k - 1) * exp(-2 * (k * lam)^2)
    end
    return min(1.0, max(0.0, p))
end

"""
    wasserstein1d(a, b)

1-Wasserstein distance between empirical measures (sorted mean absolute
difference after quantile matching).
"""
function wasserstein1d(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    sa, sb = sort(a), sort(b)
    n = max(length(sa), length(sb))
    n == 0 && return 0.0
    s = 0.0
    for i in 0:(n - 1)
        qa = sa[clamp(1 + i * (length(sa) - 1) ÷ max(n - 1, 1), 1, length(sa))]
        qb = sb[clamp(1 + i * (length(sb) - 1) ÷ max(n - 1, 1), 1, length(sb))]
        s += abs(qa - qb)
    end
    return s / n
end

"""
    energy_distance(a, b)

Energy distance (Székely & Rizzo 2004, 2013) for univariate samples:
`2 E|X−Y| − E|X−X'| − E|Y−Y'|`.
"""
function energy_distance(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    n, m = length(a), length(b)
    (n == 0 || m == 0) && return 0.0
    exy = 0.0
    @inbounds for x in a, y in b
        exy += abs(x - y)
    end
    exy /= (n * m)
    exx = 0.0
    @inbounds for i in 1:n, j in 1:n
        exx += abs(a[i] - a[j])
    end
    exx /= n^2
    eyy = 0.0
    @inbounds for i in 1:m, j in 1:m
        eyy += abs(b[i] - b[j])
    end
    eyy /= m^2
    return 2 * exy - exx - eyy
end

"""
    jensen_shannon(a, b; bins=20)

Histogram-based Jensen–Shannon divergence (Lin 1991), in nats.
"""
function jensen_shannon(
    a::AbstractVector{<:Real},
    b::AbstractVector{<:Real};
    bins::Int = 20,
)
    lo = min(minimum(a), minimum(b))
    hi = max(maximum(a), maximum(b))
    hi == lo && return 0.0
    edges = range(lo, hi; length = bins + 1)
    pa = _hist_prob(a, edges)
    pb = _hist_prob(b, edges)
    m = 0.5 .* (pa .+ pb)
    return 0.5 * _kl(pa, m) + 0.5 * _kl(pb, m)
end

function _hist_prob(x, edges)
    counts = zeros(Float64, length(edges) - 1)
    for v in x
        k = searchsortedlast(edges, v)
        k = clamp(k, 1, length(counts))
        counts[k] += 1
    end
    s = sum(counts)
    s == 0 && return fill(1 / length(counts), length(counts))
    return counts ./ s
end

function _kl(p, q)
    s = 0.0
    @inbounds for i in eachindex(p)
        p[i] > 0 && q[i] > 0 && (s += p[i] * log(p[i] / q[i]))
    end
    return s
end

"""
    bootstrap_ci(x, stat; nboot, rng, α)

Percentile bootstrap confidence interval.
"""
function bootstrap_ci(x::AbstractVector{<:Real}, stat::Function;
    nboot::Int = 400, rng::AbstractRNG = Random.default_rng(),
    α::Float64 = 0.05)
    n = length(x)
    n < 2 && return nothing
    samples = Vector{Float64}(undef, nboot)
    buf = Vector{Float64}(undef, n)
    for b in 1:nboot
        for i in 1:n
            buf[i] = x[rand(rng, 1:n)]
        end
        samples[b] = stat(buf)
    end
    qs = quantile(samples, [α / 2, 1 - α / 2])
    return (qs[1], qs[2])
end

function sample_quantile(x::AbstractVector{<:Real}, p::Real)
    isempty(x) && return NaN
    quantile(x, Float64(p))
end

function time_to_float(ts::AbstractVector{DateTime})
    isempty(ts) && return Float64[]
    t0 = ts[1]
    return [Dates.value(Millisecond(t - t0)) / 3.6e6 for t in ts]  # hours
end

function is_regular_cadence(ts::AbstractVector{DateTime}; tol = 0.35)
    length(ts) < 4 && return false
    dts = [Dates.value(ts[i] - ts[i - 1]) for i in 2:length(ts)]
    filter!(>(0), dts)
    length(dts) < 3 && return false
    med = median(dts)
    med == 0 && return false
    return mean(abs.(dts .- med) ./ med) < tol
end

"""
    boxcox(x, λ)

Box–Cox transform (Box & Cox 1964). `x` must be positive.
"""
function boxcox(x::Real, λ::Real)
    x > 0 || throw(ArgumentError("Box–Cox requires strictly positive values"))
    abs(λ) < 1e-8 ? log(x) : (x^λ - 1) / λ
end

function inv_boxcox(y::Real, λ::Real)
    if abs(λ) < 1e-8
        return exp(y)
    end
    inner = λ * y + 1
    inner <= 0 && return NaN
    inner^(1 / λ)
end

"""
    boxcox_lambda(x; grid)

Profile-likelihood estimate of the Box–Cox power on a dense grid.
"""
function boxcox_lambda(x::AbstractVector{<:Real}; grid = range(-2.0, 2.0; length = 81))
    xs = [Float64(v) for v in x if v isa Number && isfinite(Float64(v)) && v > 0]
    length(xs) < 8 && return 0.0
    slog = sum(log, xs)
    n = length(xs)
    best_λ, best_ll = 0.0, -Inf
    for λ in grid
        y = boxcox.(xs, λ)
        σ2 = var(y)
        σ2 <= 0 && continue
        ll = (λ - 1) * slog - (n / 2) * log(σ2)
        if ll > best_ll
            best_ll = ll
            best_λ = Float64(λ)
        end
    end
    best_λ
end

"""
    lms_quantile(μ, σ, λ, z)

Cole LMS quantile: `μ (1 + λ σ z)^{1/λ}` (or log-normal when `λ ≈ 0`).
"""
function lms_quantile(μ::Real, σ::Real, λ::Real, z::Real)
    μ = Float64(μ)
    σ = Float64(σ)
    λ = Float64(λ)
    z = Float64(z)
    if abs(λ) < 1e-8
        return μ * exp(σ * z)
    end
    inner = 1 + λ * σ * z
    inner <= 0 && return λ > 0 ? 0.0 : NaN
    μ * inner^(1 / λ)
end

function lms_fit(x::AbstractVector{<:Real})
    xs = [Float64(v) for v in x if v isa Number && isfinite(Float64(v)) && v > 0]
    length(xs) < 8 && throw(ArgumentError("LMS fit needs at least 8 positive values"))
    λ = boxcox_lambda(xs)
    μ = median(xs)
    μ <= 0 && (μ = mean(xs))
    if abs(λ) < 1e-8
        σ = std(log.(xs ./ μ))
    else
        σ = std(((xs ./ μ) .^ λ .- 1) ./ λ)
    end
    σ = σ > 0 && isfinite(σ) ? σ : 0.1
    (; λ, μ, σ)
end

function runs_test(resid::AbstractVector{<:Real})
    s = [sign(Float64(r)) for r in resid if isfinite(Float64(r)) && r != 0]
    n = length(s)
    n < 8 && return (statistic = 0.0, pvalue = 1.0, runs = 0, n)
    runs = 1 + count(i -> s[i] != s[i - 1], 2:n)
    n1 = count(>(0), s)
    n2 = n - n1
    μ = 1 + 2 * n1 * n2 / n
    σ2 = 2 * n1 * n2 * (2 * n1 * n2 - n) / (n^2 * (n - 1))
    z = (runs - μ) / sqrt(max(σ2, eps()))
    (statistic = z, pvalue = 2 * normal_sf(abs(z)), runs, n)
end

function excess_kurtosis(x::AbstractVector{<:Real})
    n = length(x)
    n < 4 && return 0.0
    μ = mean(x)
    m2 = mean((x .- μ) .^ 2)
    m2 == 0 && return 0.0
    m4 = mean((x .- μ) .^ 4)
    return m4 / m2^2 - 3
end

function missing_fraction(x::AbstractVector)
    n = length(x)
    n == 0 && return 0.0
    bad = count(is_invalid_obs, x)
    return bad / n
end

function fingerprint(v::AbstractVector)
    io = IOBuffer()
    write(io, UInt64(length(v)))
    for x in v
        if x isa Real && isfinite(Float64(x))
            write(io, Float64(x))
        else
            write(io, UInt64(0))
        end
    end
    return bytes2hex(sha256(take!(io)))[1:16]
end

function fingerprint(s::AbstractString)
    bytes2hex(sha256(codeunits(s)))[1:16]
end

function new_id()
    string(uuid4())[1:8]
end

function bh_adjust(pvalues::AbstractVector{<:Real})
    n = length(pvalues)
    n == 0 && return Float64[]
    order = sortperm(pvalues)
    adj = similar(pvalues, Float64)
    minp = 1.0
    for (rank, idx) in Iterators.reverse(collect(enumerate(order)))
        minp = min(minp, pvalues[idx] * n / rank)
        adj[idx] = min(1.0, minp)
    end
    return adj
end

"""
Two-sided 97.5% Student-t critical value (Higgins–Thompson prediction intervals).
"""
function _t_crit_975(df::Integer)
    df < 1 && (df = 1)
    table = (
        12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
        2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086,
        2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042,
    )
    df <= 30 && return table[df]
    1.96 + 2.4 / df
end
