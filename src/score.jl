# Sentinel Score: analytical stability, not patient risk.

const DEFAULT_SCORE_WEIGHTS = (
    drift = 0.28,
    variance = 0.16,
    qc = 0.22,
    calibration = 0.10,
    distribution = 0.16,
    missingness = 0.08,
)

const SCORE_FORMULA = """
SentinelScore = 100 − 100 × (w_drift·p_drift + w_var·p_var + w_qc·p_qc
+ w_cal·p_cal + w_dist·p_dist + w_miss·p_miss),
clipped to [0, 100]. Each p_* is a unitless penalty in [0, 1].
Weights are configurable and always stored on the result.
This score describes analytical-process stability, not patient risk.
"""

function sentinel_score(;
    drift_prob::Real = 0.0,
    variance_penalty::Real = 0.0,
    qc_penalty::Real = 0.0,
    calibration_penalty::Real = 0.0,
    distribution_penalty::Real = 0.0,
    missing_penalty::Real = 0.0,
    weights::NamedTuple = DEFAULT_SCORE_WEIGHTS,
)
    w = weights
    s = w.drift + w.variance + w.qc + w.calibration + w.distribution + w.missingness
    s == 0 && (s = 1.0)
    penalty = (
        w.drift * clamp(drift_prob, 0, 1) +
        w.variance * clamp(variance_penalty, 0, 1) +
        w.qc * clamp(qc_penalty, 0, 1) +
        w.calibration * clamp(calibration_penalty, 0, 1) +
        w.distribution * clamp(distribution_penalty, 0, 1) +
        w.missingness * clamp(missing_penalty, 0, 1)
    ) / s
    value = clamp(100 - 100 * penalty, 0.0, 100.0)
    components = (
        drift = Float64(drift_prob),
        variance = Float64(variance_penalty),
        qc = Float64(qc_penalty),
        calibration = Float64(calibration_penalty),
        distribution = Float64(distribution_penalty),
        missingness = Float64(missing_penalty),
    )
    SentinelScore(value, components, w, SCORE_FORMULA)
end

function status_from_score(score::Real, drift_detected::Bool)
    drift_detected && score < 70 && return :drift_suspected
    score >= 90 && return :stable
    score >= 75 && return :watch
    score >= 55 && return :warning
    return :critical
end
