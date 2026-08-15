# Detector evaluation on simulated ground truth.

"""
    evaluate_detector(kind; nrep=20, n=800, rng)

Compare detection delay, false-positive rate, and sensitivity on simulated
streams. Useful as a research-platform harness for new detectors.
"""
function evaluate_detector(kind::Symbol = :cusum;
    nrep::Int = 20,
    n::Int = 800,
    drift::Symbol = :step,
    drift_start::Int = 500,
    rng::AbstractRNG = Random.default_rng())
    delays = Float64[]
    tp = 0
    fp = 0
    fn = 0
    tn = 0
    for r in 1:nrep
        seed = rand(rng, UInt64)
        local_rng = Random.Xoshiro(seed)
        pos = simulate_assay(; n, drift, drift_start, rng = local_rng)
        neg = simulate_assay(; n, drift = :none, rng = Random.Xoshiro(seed + 1))
        rp = detect_changes([m.value for m in pos.stream.measurements]; method = kind)
        rn = detect_changes([m.value for m in neg.stream.measurements]; method = kind)
        if rp.detected
            tp += 1
            τ = isempty(rp.indices) ? n : minimum(rp.indices)
            push!(delays, max(0, τ - drift_start))
        else
            fn += 1
        end
        if rn.detected
            fp += 1
        else
            tn += 1
        end
    end
    (
        method = kind,
        nrep,
        n,
        drift,
        sensitivity = tp / max(tp + fn, 1),
        false_positive_rate = fp / max(fp + tn, 1),
        precision = tp / max(tp + fp, 1),
        mean_delay = isempty(delays) ? NaN : mean(delays),
        median_delay = isempty(delays) ? NaN : median(delays),
    )
end

function evaluate_detector(detector::AbstractDetector; nrep::Int = 20, n::Int = 400,
    drift::Symbol = :step, drift_start::Int = 250,
    rng::AbstractRNG = Random.default_rng())
    tp = fp = fn = tn = 0
    for _ in 1:nrep
        pos = simulate_assay(; n, drift, drift_start, rng)
        d = deepcopy(detector)
        fit!(d, [m.value for m in pos.stream.measurements[1:max(20, drift_start ÷ 3)]])
        hit = false
        for (i, m) in enumerate(pos.stream.measurements)
            update!(d, m)
            if result(d) !== nothing && alert(result(d)) && i >= drift_start
                hit = true
                break
            end
        end
        hit ? (tp += 1) : (fn += 1)
        neg = simulate_assay(; n, drift = :none, rng)
        d2 = deepcopy(detector)
        fit!(d2, [m.value for m in neg.stream.measurements[1:40]])
        hitn = false
        for m in neg.stream.measurements
            update!(d2, m)
            if result(d2) !== nothing && alert(result(d2))
                hitn = true
                break
            end
        end
        hitn ? (fp += 1) : (tn += 1)
    end
    (
        method = :custom,
        sensitivity = tp / max(tp + fn, 1),
        false_positive_rate = fp / max(fp + tn, 1),
        precision = tp / max(tp + fp, 1),
    )
end
