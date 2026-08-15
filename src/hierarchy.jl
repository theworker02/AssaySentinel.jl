# Hierarchical multi-site monitoring. Association across sites is not causation.

"""
    hierarchical_sites(data; site, value=:value, timestamps=:timestamp, method=:eb)

Random-effects site model (DerSimonian–Laird / empirical Bayes):

1. Per-site mean and SD
2. Between-site τ² and within-site σ²
3. Shrink site means toward the grand mean
4. Per-site and pooled drift
5. Cochran Q on site drift magnitudes → `:global`, `:site_specific`, `:mixed`, or `:stable`

`method=:turing` uses the Turing extension (hierarchical site intercepts +
shared change). The default `:eb` path is stdlib-only.
"""
function hierarchical_sites(data;
                            site,
                            value = :value,
                            timestamps = :timestamp,
                            method::Symbol = :eb,
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
        push!(ts, t === nothing || t isa Missing ? now() + Second(i) : DateTime(t))
    end
    hierarchical_sites(vals, sites; timestamps = ts, method, rng)
end

function hierarchical_sites(values::AbstractVector, sites::AbstractVector;
                            timestamps = nothing,
                            method::Symbol = :eb,
                            rng::AbstractRNG = Random.default_rng())
    length(values) == length(sites) ||
        throw(ArgumentError("values and sites must have the same length"))
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
    length(vals) < 12 && throw(InsufficientDataError(12, length(vals), "hierarchical_sites"))
    uniq = sort(unique(labs))
    length(uniq) < 2 && throw(ArgumentError("hierarchical_sites needs at least two sites"))

    method === :turing && return _turing_hierarchical_sites(vals, labs, ts, uniq; rng)

    groups = [vals[labs .== s] for s in uniq]
    times = [ts[labs .== s] for s in uniq]
    ns = length.(groups)
    means = mean.(groups)
    sds = [length(g) >= 2 ? std(g) : 0.0 for g in groups]
    σ2 = sum((ns[i] - 1) * sds[i]^2 for i in eachindex(uniq)) / max(sum(ns) - length(uniq), 1)
    σ2 = σ2 > 0 && isfinite(σ2) ? σ2 : 1.0
    w = [n / σ2 for n in ns]
    μ = sum(w .* means) / sum(w)
    Qloc = sum(w[i] * (means[i] - μ)^2 for i in eachindex(uniq))
    denom = sum(w) - sum(abs2, w) / sum(w)
    τ2 = denom > 0 ? max(0.0, (Qloc - (length(uniq) - 1)) / denom) : 0.0
    τ = sqrt(τ2)
    effects = SiteEffect[]
    drifts = DriftResult[]
    for i in eachindex(uniq)
        se2 = σ2 / ns[i]
        B = τ2 / (τ2 + se2)
        α = B * (means[i] - μ)
        d = length(groups[i]) >= 16 ?
            detect_drift(groups[i]; kind = :auto, timestamps = times[i], rng) :
            DriftResult(; detected = false, detector = :none, kind = :unspecified)
        push!(drifts, d)
        push!(effects, SiteEffect(uniq[i], ns[i], means[i], μ + α, sds[i], B, d))
    end

    # Site-adjusted pooled series for global drift
    adj = similar(vals)
    lookup = Dict(effects[i].site => effects[i].shrunk_mean for i in eachindex(effects))
    for i in eachindex(vals)
        adj[i] = vals[i] - (lookup[labs[i]] - μ)
    end
    global_d = detect_drift(adj; kind = :auto, timestamps = ts, rng)

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
        "k=$(length(uniq)) sites; grand mean $(round(μ; digits=3)); τ=$(round(τ; digits=3)); σ=$(round(sqrt(σ2); digits=3)).",
        "Site-mean heterogeneity Q=$(round(Qloc; digits=2)) (df=$(length(uniq)-1)).",
        "Drift heterogeneity Q=$(round(Qd; digits=2)), p=$(round(pd; digits=4)); concordance=$(round(conc; digits=2)).",
        "Attribution :$attr is a statistical description of sharing, not a cause.",
    ]
    HierarchicalSiteResult(
        effects, μ, τ, sqrt(σ2), global_d, Qd, pd, attr, conc, ev,
        "Hierarchical site model. Temporal association across sites is not causation. Not a diagnostic device.",
        (; method = :eb, Q_location = Qloc, n = length(vals), schema_version = string(SCHEMA_VERSION)),
    )
end

function _chi2_sf(q, ν)
    ν <= 0 && return 1.0
    q <= 0 && return 1.0
    # Wilson–Hilferty cube-root approximation to χ² tail
    z = ((q / ν)^(1 / 3) - (1 - 2 / (9ν))) / sqrt(2 / (9ν))
    normal_sf(z)
end

function _turing_hierarchical_sites(vals, labs, ts, uniq; rng)
    throw(ArgumentError("hierarchical_sites(...; method=:turing) requires Turing.jl. Add Turing and run `using Turing`."))
end

"""
    analyze(study, streams; rng)

Analyze each site stream and combine them with `hierarchical_sites`.
`streams` maps site name → `AssayStream`.
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
            push!(rows, (; site = string(name), value = Float64(m.value),
                         timestamp = m.timestamp))
        end
    end
    hier = hierarchical_sites(rows; site = :site, value = :value,
                              timestamps = :timestamp, rng = Random.Xoshiro(seed))
    StudyReport(study.name, hier, site_reports, SAFETY_NOTICE,
                string(SCHEMA_VERSION), string(PACKAGE_VERSION),
                (; n_sites = length(site_reports), study_sites = [s.name for s in study.sites]))
end

"""
    StudySentinel

Streaming monitor for several sites. A study-level alert fires when enough
sites alarm inside the concordance window (default: 2 sites within 7 days).
"""
mutable struct StudySentinel
    name::String
    sentinels::Dict{String, Sentinel}
    alerts::Vector{Alert}
    callbacks::Vector{Function}
    min_sites::Int
    window::Period
end

function StudySentinel(baselines::AbstractDict{<:AbstractString, Baseline};
                       name::AbstractString = "study",
                       min_sites::Int = 2,
                       window::Period = Day(7),
                       cooldown::Period = Hour(6))
    sent = Dict{String, Sentinel}()
    for (k, b) in baselines
        sent[string(k)] = Sentinel(b; cooldown)
    end
    StudySentinel(String(name), sent, Alert[], Function[], min_sites, window)
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
    recent = Alert[]
    for (s, sent) in study.sentinels
        for a in sent.alerts
            if t - a.timestamp <= study.window
                push!(recent, a)
            end
        end
    end
    sites_hit = unique(begin
        # site identity is the sentinel key that owns the alert
        [k for (k, sent) in study.sentinels if any(a -> t - a.timestamp <= study.window, sent.alerts)]
    end)
    if length(sites_hit) >= study.min_sites
        a = Alert(; severity = :warning, timestamp = t,
                  message = "Concordant analytical signals at $(length(sites_hit)) sites (not causation).",
                  kind = :hierarchical,
                  evidence = ["Sites: $(join(sites_hit, ", "))."])
        push!(study.alerts, a)
        for cb in study.callbacks
            cb(a)
        end
        return a
    end
    r
end

function Base.show(io::IO, r::HierarchicalSiteResult)
    println(io, "HierarchicalSiteResult")
    println(io, "sites: ", length(r.sites), "  attribution: ", r.attribution)
    println(io, "grand mean: ", round(r.grand_mean; digits = 3),
            "  τ: ", round(r.between_sd; digits = 3))
    print(io, "concordance: ", round(r.concordance; digits = 2))
end

function Base.show(io::IO, r::StudyReport)
    println(io, "AssaySentinel StudyReport ", r.name)
    println(io, "schema ", r.schema_version, "  package ", r.package_version)
    print(io, r.hierarchy)
end
