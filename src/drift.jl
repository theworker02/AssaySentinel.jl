# Structured drift detection. Returns DriftResult, never a bare boolean.

"""
    detect_drift(data; kind=:auto, timestamps=nothing, baseline=nothing, rng)

Detect analytical drift of a specified kind.

Kinds: `:linear`, `:nonlinear`, `:sudden`, `:cyclic`, `:variance`,
`:distribution`, `:calibration`, `:auto`.
"""
function detect_drift(data::AbstractVector;
    kind::Symbol = :auto,
    timestamps = nothing,
    baseline = nothing,
    rng::AbstractRNG = Random.default_rng())
    ts, vals = if timestamps === nothing
        DateTime[], valid_values(data)
    else
        valid_pairs(collect(timestamps), collect(data))
    end
    n = length(vals)
    n < 8 && return DriftResult(; detected = false, detector = kind, kind,
        evidence = ["Insufficient finite observations for drift analysis."])

    if kind === :auto
        results = [
            _drift_linear(vals, ts),
            _drift_sudden(vals, ts),
            _drift_variance(vals, ts),
            _drift_distribution(vals, ts, baseline),
        ]
        n >= 16 && push!(results, _drift_cyclic(vals, ts))
        n >= 20 && push!(results, _drift_nonlinear(vals, ts))
        best = results[argmax([r.probability for r in results])]
        ev = copy(best.evidence)
        push!(
            ev,
            "Auto mode compared linear, sudden, variance, and distributional drift; selected :$(best.kind).",
        )
        return DriftResult(;
            detected = best.detected,
            probability = best.probability,
            magnitude = best.magnitude,
            direction = best.direction,
            start_time = best.start_time,
            start_index = best.start_index,
            detector = :auto,
            kind = best.kind,
            evidence = ev,
            details = best.details,
        )
    elseif kind === :linear
        return _drift_linear(vals, ts)
    elseif kind === :nonlinear
        return _drift_nonlinear(vals, ts)
    elseif kind === :sudden
        return _drift_sudden(vals, ts)
    elseif kind === :cyclic
        return _drift_cyclic(vals, ts)
    elseif kind === :variance
        return _drift_variance(vals, ts)
    elseif kind === :distribution
        return _drift_distribution(vals, ts, baseline)
    elseif kind === :calibration
        return DriftResult(; detected = false, detector = :calibration, kind = :calibration,
            evidence = [
                "Calibration drift requires compare_calibrations on fitted curves.",
            ])
    else
        throw(ArgumentError("Unknown drift kind :$kind"))
    end
end

function _direction(δ::Real)
    δ > 0 ? :increase : δ < 0 ? :decrease : :none
end

function _t_at(ts::Vector{DateTime}, i::Integer)
    isempty(ts) || i < 1 || i > length(ts) ? nothing : ts[i]
end

function _drift_linear(vals, ts)
    x = isempty(ts) ? collect(1.0:length(vals)) : time_to_float(ts)
    fit = theil_sen(x, vals)
    resid = vals .- (fit.intercept .+ fit.slope .* x)
    σ = std(resid)
    σ = σ == 0 ? 1.0 : σ
    # Approximate slope SE via residual scatter / spread(x)
    sx = std(x)
    se = sx == 0 ? Inf : σ / (sx * sqrt(length(vals)))
    z = se == Inf ? 0.0 : fit.slope / se
    p = 2 * normal_sf(abs(z))
    span = maximum(x) - minimum(x)
    mag = fit.slope * span / (mean(vals) == 0 ? 1.0 : abs(mean(vals)))
    detected = p < 0.01 && abs(z) > 2.5
    DriftResult(;
        detected,
        probability = detected ? min(0.99, 1 - p) : max(0.05, 1 - p) * 0.4,
        magnitude = mag,
        direction = _direction(fit.slope),
        start_time = _t_at(ts, 1),
        start_index = 1,
        detector = :theil_sen,
        kind = :linear,
        evidence = detected ?
                   [
            "Theil–Sen slope $(round(fit.slope; sigdigits=4)) per time unit (z=$(round(z; digits=2))).",
        ] :
                   String["No significant linear trend (Theil–Sen)."],
        details = (; slope = fit.slope, intercept = fit.intercept, z, p),
    )
end

function _drift_nonlinear(vals, ts)
    x = isempty(ts) ? collect(1.0:length(vals)) : time_to_float(ts)
    n = length(vals)
    # Compare linear vs quadratic residual sum of squares
    lin = theil_sen(x, vals)
    r1 = sum(abs2, vals .- (lin.intercept .+ lin.slope .* x))
    # Simple least-squares quadratic
    X = hcat(ones(n), x, x .^ 2)
    β = try
        X \ vals
    catch
        return DriftResult(; detected = false, detector = :quadratic, kind = :nonlinear,
            evidence = ["Quadratic fit failed."])
    end
    r2 = sum(abs2, vals .- X * β)
    f = ((r1 - r2) / 1) / (r2 / max(n - 3, 1))
    detected = f > 6 && r2 < 0.92 * r1
    DriftResult(;
        detected,
        probability = detected ? min(0.95, 0.5 + f / 40) : 0.15,
        magnitude = β[3] * (maximum(x) - minimum(x))^2 / (abs(mean(vals)) + eps()),
        direction = _direction(β[3]),
        start_time = _t_at(ts, 1),
        start_index = 1,
        detector = :quadratic,
        kind = :nonlinear,
        evidence = detected ?
                   [
            "Quadratic term improved residual fit (F=$(round(f; digits=2))); nonlinear drift suspected.",
        ] :
                   String["Quadratic term did not meaningfully improve a linear fit."],
        details = (; f, beta = β),
    )
end

function _drift_sudden(vals, ts)
    cp = detect_changes(vals; method = :likelihood, timestamps = isempty(ts) ? nothing : ts)
    if !cp.detected || isempty(cp.indices)
        return DriftResult(; detected = false, detector = :likelihood, kind = :sudden,
            evidence = ["No sudden mean shift localized."])
    end
    τ = cp.indices[1]
    left = vals[1:τ]
    right = vals[(τ + 1):end]
    μ1, μ2 = mean(left), mean(right)
    mag = (μ2 - μ1) / (abs(μ1) + eps())
    DriftResult(;
        detected = true,
        probability = cp.confidence,
        magnitude = mag,
        direction = _direction(μ2 - μ1),
        start_time = isempty(cp.timestamps) ? _t_at(ts, τ) : cp.timestamps[1],
        start_index = τ,
        detector = :likelihood,
        kind = :sudden,
        evidence = cp.evidence,
        details = (; tau = τ, mean_before = μ1, mean_after = μ2),
    )
end

function _drift_variance(vals, ts)
    # Inclán–Tiao (1994) ICSS / CUSUM of squares
    n = length(vals)
    e2 = abs2.(vals .- mean(vals))
    C = cumsum(e2)
    total = C[end]
    total <= 0 &&
        return DriftResult(; detected = false, detector = :icss, kind = :variance,
            evidence = ["Zero residual energy."])
    D = [C[k] / total - k / n for k in 1:n]
    τ = argmax(abs.(D))
    stat = sqrt(n / 2) * maximum(abs.(D))
    # Asymptotic 5% critical value ≈ 1.358 for Brownian bridge supremum
    detected = stat > 1.358
    left = std(view(vals, 1:τ))
    right = std(view(vals, (τ + 1):n))
    mag = (right - left) / (left + eps())
    DriftResult(;
        detected,
        probability = detected ? min(0.98, 0.5 + (stat - 1.358) / 4) : 0.15,
        magnitude = mag,
        direction = _direction(right - left),
        start_time = _t_at(ts, τ),
        start_index = τ,
        detector = :icss,
        kind = :variance,
        evidence = detected ?
                   [
            "Inclán–Tiao CUSUM of squares exceeded the Brownian-bridge 5% critical value at observation $τ.",
        ] :
                   String["No variance change by Inclán–Tiao ICSS."],
        details = (; statistic = stat, sd_before = left, sd_after = right),
    )
end

function _drift_cyclic(vals, ts)
    n = length(vals)
    z = vals .- mean(vals)
    # Periodogram peak vs mean power ( Schuster / Fisher g-test style )
    maxp = 0.0
    sump = 0.0
    best_k = 1
    for k in 1:min(n ÷ 4, 40)
        ω = 2π * k / n
        c = 0.0
        s = 0.0
        @inbounds for t in 1:n
            c += z[t] * cos(ω * t)
            s += z[t] * sin(ω * t)
        end
        p = (c^2 + s^2) / n
        sump += p
        if p > maxp
            maxp = p
            best_k = k
        end
    end
    g = sump == 0 ? 0.0 : maxp / sump
    detected = g > 0.35 && n >= 16
    DriftResult(;
        detected,
        probability = detected ? min(0.9, g) : 0.1,
        magnitude = g,
        direction = :cyclic,
        start_time = _t_at(ts, 1),
        start_index = 1,
        detector = :periodogram,
        kind = :cyclic,
        evidence = detected ?
                   [
            "Periodogram peak at harmonic $best_k (Fisher-like g=$(round(g; digits=3))).",
        ] :
                   String["No dominant cyclic component."],
        details = (; harmonic = best_k, g),
    )
end

function _drift_distribution(vals, ts, baseline)
    ref = if baseline isa Baseline
        baseline.values
    elseif baseline isa AbstractVector
        valid_values(baseline)
    else
        n = length(vals)
        vals[1:max(1, n ÷ 3)]
    end
    cur = if baseline === nothing
        n = length(vals)
        vals[(max(1, n ÷ 3) + 1):end]
    else
        vals
    end
    (length(ref) < 8 || length(cur) < 8) &&
        return DriftResult(; detected = false, detector = :ks, kind = :distribution,
            evidence = ["Not enough observations to compare distributions."])
    d = ks_statistic(ref, cur)
    p = ks_pvalue(d, length(ref), length(cur))
    detected = p < 0.01
    DriftResult(;
        detected,
        probability = detected ? 1 - p : p < 0.1 ? 0.4 : 0.15,
        magnitude = d,
        direction = _direction(mean(cur) - mean(ref)),
        start_time = _t_at(ts, length(ref) + 1),
        start_index = length(ref) + 1,
        detector = :ks,
        kind = :distribution,
        evidence = detected ?
                   [
            "Two-sample KS D=$(round(d; digits=3)), asymptotic p=$(round(p; digits=4)).",
        ] :
                   String["Current window is consistent with the baseline distribution (KS)."],
        details = (; D = d, p),
    )
end
