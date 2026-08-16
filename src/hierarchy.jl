# Hierarchical multi-site monitoring. Association across sites is not causation.

"""
    hierarchical_sites(data; site, value=:value, timestamps=:timestamp, method=:eb)

Random-effects site model (DerSimonian–Laird / empirical Bayes):

1. Per-site mean, SD, and standard error
2. Between-site τ² and within-site σ²
3. Shrink site means toward the grand mean
4. Higgins I² and a 95% prediction interval for a new site mean
5. Per-site and pooled drift
6. Cochran Q on site drift magnitudes → `:global`, `:site_specific`, `:mixed`, or `:stable`

`method=:turing` uses the Turing extension (hierarchical site intercepts +
shared change). The default `:eb` path is stdlib-only.

Attribution is a statistical description of sharing, not a cause.
"""
function hierarchical_sites(data;
    site,
    value = :value,
    timestamps = :timestamp,
    method::Symbol = :eb,
    sampler::Symbol = :mh,
    rng::AbstractRNG = Random.default_rng())
    rows = collect(_table_rows(data))
    sites = String[]
    vals = Float64[]
    ts = DateTime[]
    for (i, r) in enumerate(rows)
        s = _rowget(r, site)
        v = _rowget(r, value)
        s === nothing && continue
        v isa Number && isfinite(Float64(v)) || continue
        push!(sites, string(s))
        push!(vals, Float64(v))
        t = _rowget(r, timestamps)
        push!(
            ts,
            t === nothing || t isa Missing ? DateTime(2020, 1, 1) + Hour(i) : DateTime(t),
        )
    end
    hierarchical_sites(vals, sites; timestamps = ts, method, sampler, rng)
end

function hierarchical_sites(values::AbstractVector, sites::AbstractVector;
    timestamps = nothing,
    method::Symbol = :eb,
    sampler::Symbol = :mh,
    rng::AbstractRNG = Random.default_rng())
    length(values) == length(sites) ||
        throw(ArgumentError("values and sites must have the same length"))
    timestamps !== nothing && length(timestamps) != length(values) &&
        throw(ArgumentError("timestamps must match values"))
    vals = Float64[]
    labs = String[]
    ts = DateTime[]
    for (i, (v, s)) in enumerate(zip(values, sites))
        v isa Number && isfinite(Float64(v)) || continue
        push!(vals, Float64(v))
        push!(labs, string(s))
        if timestamps !== nothing && i <= length(timestamps) &&
           timestamps[i] !== nothing && !(timestamps[i] isa Missing)
            push!(ts, DateTime(timestamps[i]))
        else
            push!(ts, DateTime(2020, 1, 1) + Hour(i))
        end
    end
    length(vals) < 12 &&
        throw(InsufficientDataError(12, length(vals), "hierarchical_sites"))
    uniq = sort(unique(labs))
    length(uniq) < 2 && throw(ArgumentError("hierarchical_sites needs at least two sites"))

    method === :turing && return _turing_hierarchical_sites(vals, labs, ts, uniq; rng, sampler)

    groups = [vals[labs .== s] for s in uniq]
    times = [ts[labs .== s] for s in uniq]
    ns = length.(groups)
    any(<(1), ns) && throw(ArgumentError("each site needs at least one finite value"))
    means = mean.(groups)
    sds = [length(g) >= 2 ? std(g) : 0.0 for g in groups]
    dfw = max(sum(ns) - length(uniq), 1)
    σ2_raw = sum((ns[i] - 1) * sds[i]^2 for i in eachindex(uniq)) / dfw
    has_within = σ2_raw > 0 && isfinite(σ2_raw)
    σ2 = has_within ? σ2_raw : 1.0
    ses = [
        ns[i] >= 2 && sds[i] > 0 ? sds[i] / sqrt(ns[i]) :
        (has_within ? sqrt(σ2 / ns[i]) : 0.0) for i in eachindex(uniq)
    ]
    k = length(uniq)
    if has_within
        w = [1 / max(ses[i]^2, eps()) for i in eachindex(uniq)]
        μ = sum(w .* means) / sum(w)
        Qloc = sum(w[i] * (means[i] - μ)^2 for i in eachindex(uniq))
        denom = sum(w) - sum(abs2, w) / sum(w)
        τ2 = denom > 0 ? max(0.0, (Qloc - (k - 1)) / denom) : 0.0
        i2 = Qloc > 0 ? max(0.0, 100 * (Qloc - (k - 1)) / Qloc) : 0.0
    else
        μ = mean(means)
        τ2 = k >= 2 ? var(means) : 0.0
        Qloc = (k - 1) * τ2
        i2 = 100.0
    end
    τ = sqrt(τ2)
    wstar = [1 / (max(ses[i]^2, 0.0) + τ2 + eps()) for i in eachindex(uniq)]
    se_μ = sqrt(1 / sum(wstar))
    tcrit = _t_crit_975(k - 2)
    pred_sd = sqrt(τ2 + se_μ^2)
    plo = μ - tcrit * pred_sd
    phi = μ + tcrit * pred_sd

    effects = SiteEffect[]
    drifts = DriftResult[]
    for i in eachindex(uniq)
        se2 = ses[i]^2
        B = (τ2 + se2) > 0 ? τ2 / (τ2 + se2) : 1.0
        α = B * (means[i] - μ)
        d =
            length(groups[i]) >= 16 ?
            detect_drift(groups[i]; kind = :auto, timestamps = times[i], rng) :
            DriftResult(; detected = false, detector = :none, kind = :unspecified)
        push!(drifts, d)
        push!(effects, SiteEffect(uniq[i], ns[i], means[i], μ + α, sds[i], B, ses[i], d))
    end

    # Site-adjusted pooled series for global drift
    adj = similar(vals)
    lookup = Dict(effects[i].site => effects[i].shrunk_mean for i in eachindex(effects))
    for i in eachindex(vals)
        adj[i] = vals[i] - (lookup[labs[i]] - μ)
    end
    ord = sortperm(ts)
    global_d =
        length(vals) >= 16 && has_within ?
        detect_drift(adj[ord]; kind = :auto, timestamps = ts[ord], rng) :
        DriftResult(; detected = false, detector = :none, kind = :unspecified)

    mags = Float64[]
    dirs = Symbol[]
    wm = Float64[]
    for (e, d) in zip(effects, drifts)
        d.detected || continue
        push!(mags, d.magnitude)
        push!(dirs, d.direction)
        push!(wm, e.n)
    end
    Qd, pd = 0.0, 1.0
    if length(mags) >= 2
        wδ = wm ./ sum(wm)
        δbar = sum(wδ .* mags)
        Qd = sum(wm[i] * (mags[i] - δbar)^2 for i in eachindex(mags))
        ν = length(mags) - 1
        pd = _chi2_sf(Qd, ν)
    end
    n_det = count(d -> d.detected, drifts)
    conc = if length(dirs) >= 2
        majority = count(==(first(dirs)), dirs)
        majority / length(dirs)
    else
        n_det <= 1 ? 1.0 : 0.0
    end
    attr = if n_det == 0 && !global_d.detected
        :stable
    elseif n_det >= 2 && pd < 0.05 && conc < 0.75
        :site_specific
    elseif (global_d.detected || n_det >= 2) && conc >= 0.75
        :global
    elseif n_det >= 1 || global_d.detected
        :mixed
    else
        :stable
    end
    ev = [
        "k=$(k) sites; grand mean $(round(μ; digits=3)); τ=$(round(τ; digits=3)); σ=$(round(has_within ? sqrt(σ2) : 0.0; digits=3)).",
        "Site-mean heterogeneity Q=$(round(Qloc; digits=2)) (df=$(k - 1)); I²=$(round(i2; digits=1))%$(has_within ? "" : "; within-site SD was zero so I² is 100% by convention").",
        "95% prediction interval for a new site mean: $(round(plo; digits=3)) – $(round(phi; digits=3)).",
        "Drift heterogeneity Q=$(round(Qd; digits=2)), p=$(round(pd; digits=4)); concordance=$(round(conc; digits=2)).",
        "Attribution :$attr is a statistical description of sharing, not a cause.",
    ]
    HierarchicalSiteResult(
        effects, μ, τ, has_within ? sqrt(σ2) : 0.0, global_d, Qd, pd, attr, conc, i2, plo,
        phi, ev,
        "Hierarchical site model. Temporal association across sites is not causation. Not a diagnostic device.",
        (;
            method = :eb,
            Q_location = Qloc,
            n = length(vals),
            se_mu = se_μ,
            schema_version = string(SCHEMA_VERSION),
            within_estimated = has_within,
        ),
    )
end

function _chi2_sf(q, ν)
    ν <= 0 && return 1.0
    q <= 0 && return 1.0
    # Wilson–Hilferty cube-root approximation to χ² tail
    z = ((q / ν)^(1 / 3) - (1 - 2 / (9ν))) / sqrt(2 / (9ν))
    normal_sf(z)
end

function _turing_hierarchical_sites(vals, labs, ts, uniq; rng, sampler::Symbol = :mh)
    throw(
        ArgumentError(
            "hierarchical_sites(...; method=:turing) requires Turing.jl. Add Turing and run `using Turing`.",
        ),
    )
end

"""
    analyze(study, streams; rng)

Analyze each site stream and combine them with `hierarchical_sites`.
`streams` maps site name → `AssayStream`. The study reconstruction (forest
plot, sharing narrative, uncertainty budget) is attached to the `StudyReport`.
"""
function analyze(study::Study, streams::AbstractDict;
    rng::AbstractRNG = Random.default_rng(), kwargs...)
    site_reports = Dict{String, QualityReport}()
    rows = NamedTuple[]
    seed = rand(rng, UInt64)
    for (i, (name, stream)) in enumerate(streams)
        local_rng = Random.Xoshiro(seed + UInt64(i))
        site_reports[string(name)] = analyze(stream; rng = local_rng, kwargs...)
        for m in stream.measurements
            m.value isa Number && isfinite(Float64(m.value)) || continue
            push!(
                rows,
                (; site = string(name), value = Float64(m.value),
                    timestamp = m.timestamp),
            )
        end
    end
    hier = hierarchical_sites(rows; site = :site, value = :value,
        timestamps = :timestamp, rng = Random.Xoshiro(seed))
    rec = reconstruct(hier, site_reports; rng_seed = seed, name = study.name)
    StudyReport(study.name, hier, site_reports, SAFETY_NOTICE,
        string(SCHEMA_VERSION), string(PACKAGE_VERSION),
        (; n_sites = length(site_reports), study_sites = [s.name for s in study.sites]),
        rec)
end

"""
    StudySentinel

Streaming monitor for several sites. A study-level alert fires when enough
sites alarm inside the concordance window (default: 2 sites within 7 days).
Concordance alerts themselves respect `concordance_cooldown` so a persistent
shared signal is not re-emitted on every subsequent observation.
"""
mutable struct StudySentinel
    name::String
    sentinels::Dict{String, Sentinel}
    alerts::Vector{Alert}
    callbacks::Vector{Function}
    min_sites::Int
    window::Period
    concordance_cooldown::Period
    last_concordance::Union{Nothing, DateTime}
end

function StudySentinel(baselines::AbstractDict{<:AbstractString, Baseline};
    name::AbstractString = "study",
    min_sites::Int = 2,
    window::Period = Day(7),
    cooldown::Period = Hour(6),
    concordance_cooldown::Period = cooldown)
    sent = Dict{String, Sentinel}()
    for (k, b) in baselines
        sent[string(k)] = Sentinel(b; cooldown)
    end
    StudySentinel(String(name), sent, Alert[], Function[], min_sites, window,
        concordance_cooldown, nothing)
end

function onalert(f::Function, study::StudySentinel)
    push!(study.callbacks, f)
    study
end

function update!(study::StudySentinel, site::AbstractString, measurement)
    haskey(study.sentinels, string(site)) ||
        throw(ArgumentError("unknown site $(site)"))
    r = update!(study.sentinels[string(site)], measurement)
    t = measurement isa Measurement ? measurement.timestamp : now()
    sites_hit = [
        k for (k, sent) in study.sentinels if
        any(a -> t - a.timestamp <= study.window, sent.alerts)
    ]
    if length(sites_hit) >= study.min_sites
        cooled =
            study.last_concordance === nothing ||
            t >= study.last_concordance + study.concordance_cooldown
        if cooled
            a = Alert(; severity = :warning, timestamp = t,
                message = "Concordant analytical signals at $(length(sites_hit)) sites (not causation).",
                kind = :hierarchical,
                evidence = ["Sites: $(join(sort(sites_hit), ", "))."])
            push!(study.alerts, a)
            study.last_concordance = t
            for cb in study.callbacks
                cb(a)
            end
            return a
        end
    end
    r
end

"""
    result(study::StudySentinel)

Snapshot of per-site sentinels and any study-level concordance alerts.
"""
function result(study::StudySentinel)
    (
        name = study.name,
        n_sites = length(study.sentinels),
        n_concordance_alerts = length(study.alerts),
        last_concordance = study.last_concordance,
        site_alerts = Dict(k => length(s.alerts) for (k, s) in study.sentinels),
    )
end

function Base.show(io::IO, r::HierarchicalSiteResult)
    println(io, "HierarchicalSiteResult")
    println(io, "sites: ", length(r.sites), "  attribution: ", r.attribution)
    println(io, "grand mean: ", round(r.grand_mean; digits = 3),
        "  τ: ", round(r.between_sd; digits = 3),
        "  I²: ", round(r.i2; digits = 1), "%")
    print(io, "concordance: ", round(r.concordance; digits = 2))
end

function Base.show(io::IO, r::StudyReport)
    println(io, "AssaySentinel StudyReport ", r.name)
    println(io, "schema ", r.schema_version, "  package ", r.package_version)
    print(io, r.hierarchy)
    if r.reconstruction !== nothing
        println(io)
        println(io, "Reconstruction:")
        print(io, r.reconstruction.narrative)
    end
end

function Base.summary(r::StudyReport)
    (
        name = r.name,
        n_sites = length(r.site_reports),
        attribution = r.hierarchy.attribution,
        i2 = r.hierarchy.i2,
        concordance = r.hierarchy.concordance,
    )
end
