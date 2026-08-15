function record!(timeline::EventTimeline, event::AbstractEvent)
    push!(timeline.events, event)
    sort!(timeline.events; by = event_time)
    timeline
end

function record_unique!(timeline::EventTimeline, event::AbstractEvent)
    for x in timeline.events
        if event_kind(x) === event_kind(event) && event_time(x) == event_time(event)
            return timeline
        end
    end
    record!(timeline, event)
end

record!(stream::AssayStream, event::AbstractEvent) = record!(stream.events, event)

function events_near(timeline::EventTimeline, t::DateTime; window::Period = Day(7))
    lo = t - window
    hi = t + window
    return [e for e in timeline.events if lo <= event_time(e) <= hi]
end

function lot_transitions(measurements::AbstractVector{<:Measurement})
    events = LotChangeEvent[]
    prev = nothing
    for m in measurements
        lot = m.reagent_lot
        lot === nothing && continue
        if prev !== nothing && lot != prev
            push!(events, LotChangeEvent(m.timestamp, lot; from_lot = prev))
        end
        prev = lot
    end
    events
end
