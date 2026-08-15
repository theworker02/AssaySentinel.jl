# SVG charts in core so reconstruction reports do not require Makie.

const _NAVY = "#1B2838"
const _TEAL = "#2F7A78"
const _AMBER = "#C9892A"
const _CREAM = "#F4F1EA"
const _MUTED = "#8A918A"

function _svg_esc(s)
    replace(replace(replace(string(s), "&" => "&amp;"), "<" => "&lt;"), ">" => "&gt;")
end

function _downsample(ts, vals; maxn::Int = 640)
    n = length(vals)
    n <= maxn && return collect(ts), collect(vals)
    step = cld(n, maxn)
    collect(ts[1:step:n]), collect(vals[1:step:n])
end

function _xy_scale(xs, ys, x0, y0, w, h; padx = 8.0, pady = 12.0)
    xmin, xmax = extrema(xs)
    ymin, ymax = extrema(ys)
    xmax == xmin && (xmax = xmin + 1)
    ymax == ymin && (ymax = ymin + 1)
    function mapx(x)
        x0 + padx + (x - xmin) / (xmax - xmin) * (w - 2padx)
    end
    function mapy(y)
        y0 + h - pady - (y - ymin) / (ymax - ymin) * (h - 2pady)
    end
    mapx, mapy, (xmin, xmax, ymin, ymax)
end

"""
    svg_control_chart(timestamps, values; spec, events, changepoints)

Levey–Jennings-style SVG: series, center, ±1/2/3 SD, events, change points.
"""
function svg_control_chart(timestamps::AbstractVector, values::AbstractVector;
                           spec::Union{Nothing, QCSpec} = nothing,
                           events = AbstractEvent[],
                           changepoints = DateTime[],
                           title = "Control chart")
    isempty(values) && return "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
    ts, vs = _downsample(timestamps, values)
    t0 = ts[1]
    xs = [Dates.value(Millisecond(t - t0)) / 3.6e6 for t in ts]
    μ = spec === nothing ? mean(vs) : spec.mean
    σ = spec === nothing ? std(vs) : spec.sd
    σ = σ == 0 || !isfinite(σ) ? 1.0 : σ
    guide = [μ - 3σ, μ - 2σ, μ - σ, μ, μ + σ, μ + 2σ, μ + 3σ]
    W, H = 820.0, 280.0
    mapx, mapy, _ = _xy_scale(xs, vcat(vs, guide), 40, 28, W - 50, H - 48)
    io = IOBuffer()
    println(io, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $H" role="img" aria-label="$(_svg_esc(title))">""")
    println(io, """<rect width="$W" height="$H" fill="$_CREAM"/>""")
    println(io, """<text x="16" y="20" fill="$_NAVY" font-family="Segoe UI, sans-serif" font-size="13">$(_svg_esc(title))</text>""")
    for (k, y, col, dash) in (
        (3, μ + 3σ, "#8B2E2E", "4 3"),
        (2, μ + 2σ, _AMBER, "3 3"),
        (1, μ + σ, _TEAL, "2 2"),
        (0, μ, _NAVY, "0"),
        (-1, μ - σ, _TEAL, "2 2"),
        (-2, μ - 2σ, _AMBER, "3 3"),
        (-3, μ - 3σ, "#8B2E2E", "4 3"),
    )
        yy = mapy(y)
        ds = dash == "0" ? "" : " stroke-dasharray=\"$dash\""
        println(io, """<line x1="48" y1="$yy" x2="$(W - 12)" y2="$yy" stroke="$col" stroke-width="$(k == 0 ? 1.6 : 0.8)"$ds/>""")
    end
    pts = IOBuffer()
    for (x, y) in zip(xs, vs)
        print(pts, mapx(x), ",", mapy(y), " ")
    end
    println(io, """<polyline fill="none" stroke="$_NAVY" stroke-width="1.2" points="$(String(take!(pts)))"/>""")
    for e in events
        t = event_time(e)
        xv = mapx(Dates.value(Millisecond(t - t0)) / 3.6e6)
        println(io, """<line x1="$xv" y1="32" x2="$xv" y2="$(H - 20)" stroke="$_TEAL" stroke-width="1" stroke-dasharray="3 2"/>""")
        println(io, """<text x="$(xv + 3)" y="42" fill="$_TEAL" font-size="9" font-family="Segoe UI, sans-serif">$(_svg_esc(event_kind(e)))</text>""")
    end
    for t in changepoints
        xv = mapx(Dates.value(Millisecond(t - t0)) / 3.6e6)
        println(io, """<line x1="$xv" y1="32" x2="$xv" y2="$(H - 20)" stroke="$_AMBER" stroke-width="1.6"/>""")
    end
    println(io, "</svg>")
    String(take!(io))
end

"""
    svg_timeline(beats)

Horizontal reconstruction track: Stable → Calibration → …
"""
function svg_timeline(beats::Vector{StoryBeat})
    n = max(length(beats), 1)
    W = max(820.0, 140.0 * n)
    H = 110.0
    bw = (W - 40) / n
    io = IOBuffer()
    println(io, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $H" role="img" aria-label="Analytical reconstruction timeline">""")
    println(io, """<rect width="$W" height="$H" fill="$_CREAM"/>""")
    println(io, """<text x="16" y="18" fill="$_NAVY" font-family="Segoe UI, sans-serif" font-size="13">Reconstruction timeline</text>""")
    for (i, b) in enumerate(beats)
        x = 20 + (i - 1) * bw
        fill = b.kind === :stable ? _TEAL :
               b.kind === :drift || b.kind === :shift ? _AMBER :
               b.kind === :qc || b.kind === :variance ? "#8B2E2E" : _NAVY
        println(io, """<rect x="$x" y="36" width="$(bw - 16)" height="44" rx="6" fill="$fill"/>""")
        println(io, """<text x="$(x + 8)" y="62" fill="$_CREAM" font-size="11" font-family="Segoe UI, sans-serif">$(_svg_esc(b.label))</text>""")
        if i < n
            ax = x + bw - 14
            println(io, """<text x="$ax" y="64" fill="$_NAVY" font-size="14">↓</text>""")
        end
    end
    println(io, "</svg>")
    String(take!(io))
end

"""
    svg_provenance(records)

Vertical provenance graph of analysis steps.
"""
function svg_provenance(records::Vector{ProvenanceRecord})
    n = max(length(records), 1)
    W, row = 820.0, 36.0
    H = 28 + n * row
    io = IOBuffer()
    println(io, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $H" role="img" aria-label="Provenance graph">""")
    println(io, """<rect width="$W" height="$H" fill="$_CREAM"/>""")
    println(io, """<text x="16" y="18" fill="$_NAVY" font-family="Segoe UI, sans-serif" font-size="13">Provenance</text>""")
    for (i, r) in enumerate(records)
        y = 14 + i * row
        println(io, """<rect x="40" y="$(y - 14)" width="$(W - 60)" height="28" rx="4" fill="$_NAVY"/>""")
        label = "$(r.operation) → $(r.func)  [$(r.statement_kind)]  fp=$(r.input_fingerprint)"
        println(io, """<text x="50" y="$(y + 4)" fill="$_CREAM" font-size="10" font-family="Consolas, monospace">$(_svg_esc(label))</text>""")
        if i < n
            println(io, """<line x1="52" y1="$(y + 14)" x2="52" y2="$(y + row - 14)" stroke="$_TEAL" stroke-width="2"/>""")
        end
    end
    println(io, "</svg>")
    String(take!(io))
end

"""
    svg_group_chart(labels, values; title)

Strip chart with group quartiles for lot or instrument comparison.
"""
function svg_group_chart(labels::AbstractVector, values::AbstractVector;
                         title = "Group comparison")
    labs = String[]
    vs = Float64[]
    for (l, v) in zip(labels, values)
        v isa Number && isfinite(Float64(v)) || continue
        push!(labs, string(l))
        push!(vs, Float64(v))
    end
    isempty(vs) && return "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
    groups = unique(labs)
    W, H = 820.0, 280.0
    padl, padr, padt, padb = 48.0, 16.0, 32.0, 36.0
    ymin, ymax = extrema(vs)
    ymax == ymin && (ymax = ymin + 1)
    io = IOBuffer()
    println(io, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $H" role="img" aria-label="$(_svg_esc(title))">""")
    println(io, """<rect width="$W" height="$H" fill="$_CREAM"/>""")
    println(io, """<text x="16" y="20" fill="$_NAVY" font-family="Segoe UI, sans-serif" font-size="13">$(_svg_esc(title))</text>""")
    gw = (W - padl - padr) / length(groups)
    mapy(y) = padt + (ymax - y) / (ymax - ymin) * (H - padt - padb)
    for (k, g) in enumerate(groups)
        gv = [vs[i] for i in eachindex(vs) if labs[i] == g]
        cx = padl + (k - 0.5) * gw
        med = median(gv)
        q1, q3 = sample_quantile(gv, 0.25), sample_quantile(gv, 0.75)
        println(io, """<line x1="$(cx - 18)" y1="$(mapy(q1))" x2="$(cx - 18)" y2="$(mapy(q3))" stroke="$_TEAL" stroke-width="6"/>""")
        println(io, """<line x1="$(cx - 26)" y1="$(mapy(med))" x2="$(cx - 10)" y2="$(mapy(med))" stroke="$_NAVY" stroke-width="2"/>""")
        for (j, y) in enumerate(gv)
            jitter = ((j % 7) - 3) * 1.6
            println(io, """<circle cx="$(cx + 8 + jitter)" cy="$(mapy(y))" r="2.2" fill="$_NAVY" fill-opacity="0.55"/>""")
        end
        println(io, """<text x="$cx" y="$(H - 12)" text-anchor="middle" fill="$_NAVY" font-size="11" font-family="Segoe UI, sans-serif">$(_svg_esc(g))</text>""")
    end
    println(io, "</svg>")
    String(take!(io))
end
