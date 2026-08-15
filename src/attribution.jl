# Temporal association only. Never claim causation.

"""
    attribute_change(change_time, timeline; window=Day(7))

Score nearby operational events. Language is restricted to association.
"""
function attribute_change(change_time::DateTime, timeline::EventTimeline;
    window::Period = Day(14))
    nearby = events_near(timeline, change_time; window)
    isempty(nearby) && return AttributionResult(nothing, 0.0,
        "No operational event was recorded within the association window.",
        String[])
    best = nearby[1]
    best_s = 0.0
    for e in nearby
        dt = abs(Dates.value(Millisecond(event_time(e) - change_time))) / 86_400_000
        half = max(Dates.value(Millisecond(window)) / 86_400_000, 0.5)
        s = exp(-0.5 * (dt / (0.4 * half))^2)
        # Prefer lot / calibration / maintenance slightly
        k = event_kind(e)
        if k in (:lot_change, :calibration, :maintenance)
            s *= 1.15
        end
        if s > best_s
            best_s = min(0.99, s)
            best = e
        end
    end
    stmt = "Associated event detected: $(event_label(best)). \
            Temporal association score: $(round(best_s; digits=2)). \
            Temporal association is not evidence of causation."
    AttributionResult(best, best_s, stmt, [stmt])
end

function attribute_change(cp::ChangePointResult, timeline::EventTimeline; kwargs...)
    isempty(cp.timestamps) && return AttributionResult(nothing, 0.0,
        "Change-point timestamps were not available for association.", String[])
    attribute_change(cp.timestamps[1], timeline; kwargs...)
end
