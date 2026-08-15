# BatchSentinel: detect technical batch variation separately from correction.

"""
    detect_batch_effects(dataset; batch, value, biological_group=nothing)

Distinguish likely technical variation from variation associated with an
experimental grouping. Does **not** correct data.
"""
function detect_batch_effects(dataset;
    batch,
    value = :value,
    biological_group = nothing)
    rows = _table_rows(dataset)
    batches = String[]
    values = Float64[]
    groups = Union{Nothing, String}[]
    for r in rows
        b = _rowget(r, batch)
        v = _rowget(r, value)
        b === nothing && continue
        v isa Number && isfinite(Float64(v)) || continue
        push!(batches, string(b))
        push!(values, Float64(v))
        g = biological_group === nothing ? nothing : _rowget(r, biological_group)
        push!(groups, g === nothing ? nothing : string(g))
    end
    length(values) < 6 &&
        throw(InsufficientDataError(6, length(values), "detect_batch_effects"))
    uniq = sort(unique(batches))
    bybatch = [values[batches .== b] for b in uniq]
    kw = kruskal_wallis(bybatch)
    bio_stat = nothing
    bio_p = nothing
    interpretation = "Batch-associated rank differences were evaluated with Kruskal–Wallis."
    if biological_group !== nothing && any(g -> g !== nothing, groups)
        # Residualize by group medians, then retest batch
        gnames = [g === nothing ? "_missing" : g for g in groups]
        resid = similar(values)
        for g in unique(gnames)
            mask = gnames .== g
            resid[mask] = values[mask] .- median(values[mask])
        end
        byb2 = [resid[batches .== b] for b in uniq]
        kw2 = kruskal_wallis(byb2)
        bio = kruskal_wallis([values[gnames .== g] for g in unique(gnames)])
        bio_stat = bio.statistic
        bio_p = bio.pvalue
        interpretation = if kw2.pvalue < 0.05 && bio.pvalue >= 0.05
            "Batch differences persist after removing group location; likely technical variation."
        elseif kw2.pvalue < 0.05 && bio.pvalue < 0.05
            "Both batch and biological grouping are associated with location. Do not treat batch as purely technical."
        elseif bio.pvalue < 0.05
            "Location differences align more with the experimental grouping than with batch."
        else
            "Neither batch nor grouping shows a strong location shift."
        end
        kw = kw2
    end
    detected = kw.pvalue < 0.05
    BatchEffectResult(
        detected,
        kw.statistic,
        kw.pvalue,
        bio_stat,
        bio_p,
        interpretation,
        uniq,
        :kruskal_wallis,
        [interpretation],
        (; n = length(values)),
    )
end

function detect_batch_effects(
    stream::AssayStream;
    batch = :batch,
    biological_group = nothing,
)
    detect_batch_effects(stream.measurements; batch, value = :value, biological_group)
end

"""
    correct_batch_effects(dataset; method=:median, batch, value, biological_group=nothing)

Optional correction. Always returns a new table-like vector of named tuples
and never mutates the original. The transformation is intended to be stored
in provenance by the caller.

Methods:
- `:median` — location centering to the grand mean
- `:quantile` — batch-wise quantile matching to the pooled empirical distribution
- `:ruv` — control-anchored unwanted-variation removal (RUV-lite)
- `:combat` — parametric empirical-Bayes location/scale adjustment
  (Johnson, Li & Rabinovic 2007). Batch location `γ` and scale `δ²` are
  shrunk toward hyperparameters estimated from the batch-level moments.
  When `biological_group` is set, that design is protected (not removed).
"""
function correct_batch_effects(dataset;
    method::Symbol = :median,
    batch,
    value = :value,
    biological_group = nothing,
    control = :control)
    rows = collect(_table_rows(dataset))
    batches = [string(_rowget(r, batch)) for r in rows]
    vals = Float64[_num_or_nan(_rowget(r, value)) for r in rows]
    finite = isfinite.(vals)
    groups = if biological_group === nothing
        nothing
    else
        [
            begin
                g = _rowget(r, biological_group)
                g === nothing ? "_missing" : string(g)
            end for r in rows
        ]
    end
    if method === :combat
        corrected, transform = _combat_eb(vals, batches, finite, groups)
    elseif method === :quantile
        corrected, transform = _quantile_batch(vals, batches, finite)
    elseif method === :ruv
        ctr = [_truthy(_rowget(r, control)) for r in rows]
        corrected, transform = _ruv_lite(vals, batches, finite, ctr)
    else
        corrected, transform = _median_center(vals, batches, finite)
    end
    out = [
        merge(_row_named(r), (; corrected = corrected[i], original = vals[i]))
        for (i, r) in enumerate(rows)
    ]
    return (data = out, transform = transform, method = method, original_preserved = true)
end

function _median_center(vals, batches, finite)
    uniq = sort(unique(batches[finite]))
    corrected = copy(vals)
    transform = Dict{String, NamedTuple}()
    grand = mean(vals[finite])
    for b in uniq
        mask = (batches .== b) .& finite
        xb = vals[mask]
        μb = median(xb)
        corrected[mask] = xb .- μb .+ grand
        transform[b] = (; median = μb, method = :median)
    end
    return corrected, transform
end

"""
Parametric ComBat for a univariate measurement with empirical-Bayes
shrinkage of batch location and scale (Johnson et al. 2007).

With one feature, hyperparameters are estimated across batches (hierarchical
shrinkage of `γ_b`, `δ_b²`). The protected design `groups` is residualized
out before standardization and added back after adjustment.
"""
function _combat_eb(vals::Vector{Float64}, batches::Vector{String},
    finite::AbstractVector{Bool},
    groups::Union{Nothing, Vector{String}})
    y = vals[finite]
    bfin = batches[finite]
    uniq = sort(unique(bfin))
    length(uniq) < 2 && throw(ArgumentError("ComBat needs at least two batches"))
    n = length(y)
    # Protected design: intercept + group dummies (drop first level)
    X = ones(n, 1)
    if groups !== nothing
        gfin = groups[finite]
        glv = sort(unique(gfin))
        if length(glv) >= 2
            D = zeros(n, length(glv) - 1)
            for (j, g) in enumerate(glv[2:end])
                D[:, j] .= gfin .== g
            end
            X = hcat(X, D)
        end
    end
    β = X \ y
    resid = y .- X * β
    σ = std(resid)
    σ = σ == 0 || !isfinite(σ) ? 1.0 : σ
    z = resid ./ σ

    γhat = Dict{String, Float64}()
    δ2hat = Dict{String, Float64}()
    nb = Dict{String, Int}()
    for b in uniq
        zb = z[bfin .== b]
        nb[b] = length(zb)
        γhat[b] = mean(zb)
        v = length(zb) >= 2 ? var(zb) : 1.0
        δ2hat[b] = v <= 0 || !isfinite(v) ? 1.0 : v
    end
    γs = [γhat[b] for b in uniq]
    d2s = [δ2hat[b] for b in uniq]
    μγ = mean(γs)
    τ2 = length(γs) >= 2 ? var(γs) : 0.0
    τ2 = max(τ2, 1e-6)
    md = mean(d2s)
    vd = length(d2s) >= 2 ? var(d2s) : 0.0
    # Inverse-gamma method of moments: E = θ/(λ-1), Var = θ²/((λ-1)²(λ-2))
    λ = vd > 1e-12 ? max(2.01, 2 + md^2 / vd) : 20.0
    θ = md * (λ - 1)
    θ = max(θ, 1e-8)

    γstar = Dict{String, Float64}()
    δ2star = Dict{String, Float64}()
    for b in uniq
        γstar[b] = γhat[b]
        δ2star[b] = δ2hat[b]
    end
    # Iterate location/scale posteriors (sva::ComBat style)
    for _ in 1:8
        for b in uniq
            n_b = nb[b]
            # γ | data ~ N, precision n/δ² + 1/τ²
            prec_data = n_b / max(δ2star[b], 1e-8)
            prec_prior = 1 / τ2
            γstar[b] = (prec_data * γhat[b] + prec_prior * μγ) / (prec_data + prec_prior)
            sse = 0.0
            @inbounds for (zi, bi) in zip(z, bfin)
                bi == b || continue
                sse += (zi - γstar[b])^2
            end
            # IG(λ, θ) + SSE/2  →  posterior mean θ' / (λ' - 1)
            λn = λ + n_b / 2
            θn = θ + 0.5 * sse
            δ2star[b] = θn / max(λn - 1, 1e-6)
        end
    end

    zadj = similar(z)
    @inbounds for i in eachindex(z)
        b = bfin[i]
        zadj[i] = (z[i] - γstar[b]) / sqrt(max(δ2star[b], 1e-8))
    end
    yadj = zadj .* σ .+ X * β
    corrected = copy(vals)
    corrected[finite] = yadj
    transform = Dict{String, NamedTuple}()
    for b in uniq
        transform[b] = (;
            gamma_hat = γhat[b],
            gamma_star = γstar[b],
            delta2_hat = δ2hat[b],
            delta2_star = δ2star[b],
            n = nb[b],
            method = :combat,
        )
    end
    transform["_hyper"] = (; mu_gamma = μγ, tau2 = τ2, lambda = λ, theta = θ,
        sigma = σ, empirical_bayes = true)
    return corrected, transform
end

function _quantile_batch(vals, batches, finite)
    uniq = sort(unique(batches[finite]))
    pooled = sort(vals[finite])
    np = length(pooled)
    corrected = copy(vals)
    transform = Dict{String, NamedTuple}()
    for b in uniq
        mask = (batches .== b) .& finite
        xb = vals[mask]
        nb = length(xb)
        ord = sortperm(xb)
        adj = similar(xb)
        for (r, i) in enumerate(ord)
            q = nb == 1 ? 0.5 : (r - 0.5) / nb
            idx = clamp(round(Int, q * (np - 1) + 1), 1, np)
            adj[i] = pooled[idx]
        end
        corrected[mask] = adj
        transform[b] = (; n = nb, method = :quantile)
    end
    return corrected, transform
end

function _ruv_lite(vals, batches, finite, controls::AbstractVector{Bool})
    ctrl = finite .& controls
    if count(ctrl) < 4
        corr, tr = _median_center(vals, batches, finite)
        tr["_note"] = (; method = :ruv, fallback = :median,
            notes = "Fewer than 4 controls; fell back to median centering.")
        return corr, tr
    end
    grand_c = mean(vals[ctrl])
    corrected = copy(vals)
    transform = Dict{String, NamedTuple}()
    for b in sort(unique(batches[finite]))
        bmask = (batches .== b) .& finite
        cmask = bmask .& controls
        δ = count(cmask) >= 2 ? mean(vals[cmask]) - grand_c : 0.0
        corrected[bmask] = vals[bmask] .- δ
        transform[b] = (; control_shift = δ, n_controls = count(cmask), method = :ruv)
    end
    return corrected, transform
end

"""
    correct_batch_effects(X, batch; method=:combat, design=nothing)

Multi-feature ComBat. `X` is observations × features. Empirical-Bayes
priors for each batch are estimated **across features** (Johnson et al. 2007).
"""
function correct_batch_effects(X::AbstractMatrix, batch::AbstractVector;
    method::Symbol = :combat,
    design = nothing)
    n, p = size(X)
    length(batch) == n || throw(ArgumentError("batch length must match rows of X"))
    method === :combat ||
        throw(ArgumentError("matrix correct_batch_effects supports :combat"))
    batches = string.(batch)
    Y = Matrix{Float64}(X)
    corrected, transform = _combat_eb_matrix(Y, batches, design)
    return (
        data = corrected,
        transform = transform,
        method = :combat,
        original_preserved = true,
    )
end

function _combat_eb_matrix(Y::Matrix{Float64}, batches::Vector{String}, design)
    n, p = size(Y)
    uniq = sort(unique(batches))
    length(uniq) < 2 && throw(ArgumentError("ComBat needs at least two batches"))
    X = ones(n, 1)
    if design !== nothing
        D =
            design isa AbstractMatrix ? Float64.(design) :
            throw(ArgumentError("design must be a matrix"))
        size(D, 1) == n || throw(ArgumentError("design rows must match observations"))
        X = hcat(X, D)
    end
    B = X \ Y
    resid = Y .- X * B
    σ = [
        begin
            s = std(resid[:, j])
            s == 0 || !isfinite(s) ? 1.0 : s
        end for j in 1:p
    ]
    Z = resid ./ σ'
    γhat = Dict{String, Vector{Float64}}()
    δ2hat = Dict{String, Vector{Float64}}()
    nb = Dict{String, Int}()
    for b in uniq
        idx = findall(==(b), batches)
        nb[b] = length(idx)
        Zb = Z[idx, :]
        γhat[b] = vec(mean(Zb; dims = 1))
        δ2hat[b] = [
            begin
                v = var(Zb[:, j])
                v <= 0 || !isfinite(v) ? 1.0 : v
            end for j in 1:p
        ]
    end
    # Priors across features, per batch (classic ComBat)
    γstar = Dict{String, Vector{Float64}}()
    δ2star = Dict{String, Vector{Float64}}()
    hyper = Dict{String, NamedTuple}()
    for b in uniq
        μγ = mean(γhat[b])
        τ2 = max(var(γhat[b]), 1e-6)
        md = mean(δ2hat[b])
        vd = var(δ2hat[b])
        λ = vd > 1e-12 ? max(2.01, 2 + md^2 / vd) : 20.0
        θ = max(md * (λ - 1), 1e-8)
        g = copy(γhat[b])
        d2 = copy(δ2hat[b])
        n_b = nb[b]
        for _ in 1:6
            for j in 1:p
                prec_data = n_b / max(d2[j], 1e-8)
                prec_prior = 1 / τ2
                g[j] = (prec_data * γhat[b][j] + prec_prior * μγ) / (prec_data + prec_prior)
                sse = 0.0
                @inbounds for i in 1:n
                    batches[i] == b || continue
                    sse += (Z[i, j] - g[j])^2
                end
                d2[j] = (θ + 0.5 * sse) / max(λ + n_b / 2 - 1, 1e-6)
            end
        end
        γstar[b] = g
        δ2star[b] = d2
        hyper[b] = (; mu_gamma = μγ, tau2 = τ2, lambda = λ, theta = θ, n = n_b)
    end
    Zadj = similar(Z)
    @inbounds for i in 1:n, j in 1:p
        b = batches[i]
        Zadj[i, j] = (Z[i, j] - γstar[b][j]) / sqrt(max(δ2star[b][j], 1e-8))
    end
    Yadj = Zadj .* σ' .+ X * B
    transform = Dict{String, NamedTuple}()
    for b in uniq
        transform[b] = (; gamma_star = γstar[b], delta2_star = δ2star[b],
            hyper = hyper[b], method = :combat, empirical_bayes = true)
    end
    return Yadj, transform
end

_num_or_nan(x) = x isa Number && isfinite(Float64(x)) ? Float64(x) : NaN

function _table_rows(dataset)
    if dataset isa AbstractVector
        return dataset
    end
    for m in values(Base.loaded_modules)
        if nameof(m) === :Tables && isdefined(m, :istable) && m.istable(dataset)
            return m.rows(dataset)
        end
    end
    mod = parentmodule(typeof(dataset))
    if isdefined(mod, :eachrow)
        return mod.eachrow(dataset)
    end
    throw(ArgumentError("dataset must be a table, measurements, or row vector"))
end

function _rowget(r::Measurement, col)
    col === :value && return r.value
    col === :batch && return r.batch
    col === :lot && return r.reagent_lot
    col === :reagent_lot && return r.reagent_lot
    col === :instrument && return r.instrument
    col === :timestamp && return r.timestamp
    col === :control && return r.control
    return nothing
end

function _rowget(r, col)
    if r isa NamedTuple
        return get(r, col, get(r, Symbol(col), nothing))
    end
    try
        return getproperty(r, col isa Symbol ? col : Symbol(col))
    catch
        return nothing
    end
end

function _row_named(r::Measurement)
    (; value = r.value, batch = r.batch, instrument = r.instrument,
        reagent_lot = r.reagent_lot, timestamp = r.timestamp)
end

function _row_named(r::NamedTuple)
    r
end

function _row_named(r)
    NamedTuple{propertynames(r)}(Tuple(getproperty(r, p) for p in propertynames(r)))
end
