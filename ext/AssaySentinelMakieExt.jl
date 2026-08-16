module AssaySentinelMakieExt

using AssaySentinel
using Makie
using Dates
using Statistics

"""
    levey_jennings(values, spec; timestamps, events, changepoints)

Levey–Jennings control chart with center line, ±1/2/3 SD, events, and
optional change points.
"""
function AssaySentinel.levey_jennings(values, spec::AssaySentinel.QCSpec;
    timestamps = nothing,
    events = AssaySentinel.AbstractEvent[],
    changepoints = DateTime[])
    data = AssaySentinel.levey_jennings_data(values, spec; timestamps, events)
    fig = Figure(; size = (900, 420), backgroundcolor = :white)
    ax = Axis(fig[1, 1];
        title = "Levey–Jennings control chart",
        xlabel = "observation",
        ylabel = "value",
        titlesize = 16)
    x =
        timestamps === nothing ? collect(1:length(data.values)) :
        [Dates.value(Millisecond(t - timestamps[1])) / 3.6e6 for t in data.timestamps]
    hlines!(ax, [data.center]; color = "#1B2838", linewidth = 2)
    for (y, col, ls) in (
        (data.limits.p1, "#2F7A78", :dash),
        (data.limits.m1, "#2F7A78", :dash),
        (data.limits.p2, "#C9892A", :dot),
        (data.limits.m2, "#C9892A", :dot),
        (data.limits.p3, "#8B2E2E", :dashdot),
        (data.limits.m3, "#8B2E2E", :dashdot),
    )
        hlines!(ax, [y]; color = col, linestyle = ls, linewidth = 1)
    end
    scatterlines!(ax, x, data.values; color = "#1B2838", markersize = 6)
    for e in events
        t = AssaySentinel.event_time(e)
        xv =
            timestamps === nothing ? 0.0 :
            Dates.value(Millisecond(t - timestamps[1])) / 3.6e6
        vlines!(ax, [xv]; color = "#2F7A78", linestyle = :dash)
    end
    for t in changepoints
        xv =
            timestamps === nothing ? 0.0 :
            Dates.value(Millisecond(t - timestamps[1])) / 3.6e6
        vlines!(ax, [xv]; color = "#C9892A", linewidth = 2)
    end
    fig
end

function AssaySentinel.levey_jennings(
    control::AssaySentinel.ControlSample,
    measurements;
    kwargs...,
)
    vals =
        eltype(measurements) <: AssaySentinel.Measurement ?
        [m.value for m in measurements] : measurements
    AssaySentinel.levey_jennings(vals, AssaySentinel.QCSpec(control); kwargs...)
end

function AssaySentinel.lot_chart(data; lot = :lot, value = :value)
    _group_figure(data, lot, value, "Reagent lot comparison")
end

function AssaySentinel.instrument_chart(data; instrument = :instrument, value = :value)
    _group_figure(data, instrument, value, "Instrument comparison")
end

function _group_figure(data, groupcol, value, title)
    rows = AssaySentinel._table_rows(data)
    labs = String[]
    vs = Float64[]
    for r in rows
        g = AssaySentinel._rowget(r, groupcol)
        v = AssaySentinel._rowget(r, value)
        g === nothing && continue
        v isa Number && isfinite(Float64(v)) || continue
        push!(labs, string(g))
        push!(vs, Float64(v))
    end
    groups = unique(labs)
    fig = Figure(; size = (900, 420), backgroundcolor = :white)
    ax = Axis(fig[1, 1]; title, xlabel = "group", ylabel = "value", titlesize = 16)
    for (k, g) in enumerate(groups)
        gv = [vs[i] for i in eachindex(vs) if labs[i] == g]
        xs = [Float64(k) + 0.08 * (((i % 7) - 3) / 3) for i in eachindex(gv)]
        scatter!(ax, xs, gv; color = "#1B2838", markersize = 7)
        m = median(gv)
        lines!(ax, [k - 0.28, k + 0.28], [m, m]; color = "#2F7A78", linewidth = 2)
    end
    ax.xticks = (1:length(groups), groups)
    fig
end

"""
    forest_chart(result::HierarchicalSiteResult)

Makie forest plot: raw means ± 1.96 SE, shrunk means, grand mean, and
95% prediction-interval guides. Sharing is statistical, not causal.
"""
function AssaySentinel.forest_chart(result::AssaySentinel.HierarchicalSiteResult)
    sites = result.sites
    fig = Figure(; size = (900, max(280, 48 * length(sites) + 80)), backgroundcolor = :white)
    ax = Axis(fig[1, 1];
        title = "Site forest (not causal)",
        xlabel = "mean",
        ylabel = "site",
        titlesize = 16,
        yreversed = true)
    ys = collect(1:length(sites))
    raw = [s.raw_mean for s in sites]
    se = [s.se > 0 && isfinite(s.se) ? s.se : 0.0 for s in sites]
    shrunk = [s.shrunk_mean for s in sites]
    errorbars!(ax, raw, ys, 1.96 .* se; direction = :x, color = "#2F7A78", whiskerwidth = 8)
    scatter!(ax, raw, ys; color = :transparent, strokecolor = "#1B2838",
        strokewidth = 1.4, markersize = 10)
    scatter!(ax, shrunk, ys; color = "#C9892A", markersize = 11, marker = :rect)
    vlines!(ax, [result.grand_mean]; color = "#1B2838", linewidth = 2)
    vlines!(ax, [result.prediction_lo, result.prediction_hi];
        color = "#8A918A", linestyle = :dash, linewidth = 1)
    ax.yticks = (ys, [s.site for s in sites])
    fig
end

end
