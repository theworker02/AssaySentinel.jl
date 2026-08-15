# Reproducible reports: Markdown, HTML, JSON, and .assay serialization.

function save(report::QualityReport, path::AbstractString)
    ext = lowercase(splitext(path)[2])
    if ext == ".assay"
        open(path, "w") do io
            serialize(io, report)
        end
    elseif ext == ".json"
        open(path, "w") do io
            print(io, json_string(report_dict(report)))
        end
    elseif ext == ".md" || ext == ".markdown"
        write(path, markdown_report(report))
    elseif ext == ".html" || ext == ".htm"
        write(path, html_report(report))
    else
        throw(ArgumentError("Unsupported report extension '$ext'. Use .assay, .json, .md, or .html"))
    end
    path
end

"""
    report(result, path)

Write a professional analytical report. Alias of `save` for path targets.
"""
function report(result::QualityReport, path::AbstractString)
    save(result, path)
end

function report(result::QualityReport)
    markdown_report(result)
end

function report(result::StudyReport)
    io = IOBuffer()
    println(io, "# AssaySentinel study report — ", result.name)
    println(io)
    println(io, "> ", result.safety_notice)
    println(io)
    println(io, "schema ", result.schema_version, "  package ", result.package_version)
    println(io)
    println(io, "## Hierarchical combine")
    for e in result.hierarchy.evidence
        println(io, "- ", e)
    end
    println(io)
    println(io, "Attribution: `", result.hierarchy.attribution, "` (not causation)")
    String(take!(io))
end

function report(result::StudyReport, path::AbstractString)
    ext = lowercase(splitext(path)[2])
    if ext == ".md" || ext == ".markdown"
        write(path, report(result))
    elseif ext == ".json"
        write(path, json_string(Dict(
            "name" => result.name,
            "schema_version" => result.schema_version,
            "package_version" => result.package_version,
            "attribution" => string(result.hierarchy.attribution),
            "grand_mean" => result.hierarchy.grand_mean,
            "between_sd" => result.hierarchy.between_sd,
            "concordance" => result.hierarchy.concordance,
            "evidence" => result.hierarchy.evidence,
            "sites" => collect(keys(result.site_reports)),
        )))
    else
        throw(ArgumentError("StudyReport save supports .md and .json"))
    end
    path
end

function load_report(path::AbstractString)
    ext = lowercase(splitext(path)[2])
    if ext == ".assay"
        return open(deserialize, path)
    elseif ext == ".json"
        return json_parse(read(path, String))
    else
        throw(ArgumentError("load_report supports .assay and .json"))
    end
end

function _reconstruction_dict(rec::Nothing)
    nothing
end

function _reconstruction_dict(rec::Reconstruction)
    ub = rec.uncertainty
    Dict(
        "narrative" => rec.narrative,
        "beats" => [Dict(
            "label" => b.label,
            "kind" => string(b.kind),
            "timestamp" => b.timestamp === nothing ? nothing : string(b.timestamp),
            "index" => b.index,
            "statement_kind" => string(b.statement_kind),
            "notes" => b.notes,
        ) for b in rec.beats],
        "uncertainty" => Dict(
            "n_with_uncertainty" => ub.n_with_uncertainty,
            "rms_measurement" => ub.rms_measurement,
            "analytical_sd" => ub.analytical_sd,
            "combined_sd" => ub.combined_sd,
            "weighted_mean" => ub.weighted_mean,
            "magnitude_se" => ub.magnitude_se,
            "notes" => ub.notes,
        ),
        "provenance_graph" => Dict(
            "nodes" => [[a, b, c] for (a, b, c) in rec.provenance_graph.nodes],
            "edges" => [[a, b] for (a, b) in rec.provenance_graph.edges],
        ),
        "rng_seed" => rec.rng_seed === nothing ? nothing : string(rec.rng_seed),
        "input_fingerprint" => rec.input_fingerprint,
        "package_version" => rec.package_version,
        "lot_evidence" => rec.lot_analysis === nothing ? nothing : collect(rec.lot_analysis.evidence),
        "instrument_evidence" => rec.instrument_analysis === nothing ? nothing :
            collect(rec.instrument_analysis.evidence),
    )
end

function report_dict(r::QualityReport)
    Dict(
        "package" => "AssaySentinel.jl",
        "version" => string(PACKAGE_VERSION),
        "schema_version" => string(SCHEMA_VERSION),
        "api_stable_since" => string(API_STABLE_SINCE),
        "safety_notice" => r.safety_notice,
        "analyte" => string(r.analyte),
        "unit" => r.unit,
        "status" => string(r.status),
        "status_label" => _status_label(r.status),
        "n" => r.n,
        "score" => Dict(
            "value" => r.score.value,
            "components" => Dict(string(k) => getfield(r.score.components, k) for k in keys(r.score.components)),
            "weights" => Dict(string(k) => getfield(r.score.weights, k) for k in keys(r.score.weights)),
            "formula" => r.score.formula,
        ),
        "drift" => Dict(
            "detected" => r.drift.detected,
            "probability" => r.drift.probability,
            "magnitude" => r.drift.magnitude,
            "direction" => string(r.drift.direction),
            "kind" => string(r.drift.kind),
            "detector" => string(r.drift.detector),
            "start_time" => r.drift.start_time === nothing ? nothing : string(r.drift.start_time),
            "evidence" => r.drift.evidence,
        ),
        "change_points" => Dict(
            "detected" => r.change_points.detected,
            "method" => string(r.change_points.method),
            "selection_reason" => r.change_points.selection_reason,
            "indices" => r.change_points.indices,
            "confidence" => r.change_points.confidence,
        ),
        "evidence" => r.evidence,
        "limitations" => r.limitations,
        "reconstruction" => _reconstruction_dict(r.reconstruction),
        "provenance" => [Dict(
            "id" => p.id,
            "operation" => string(p.operation),
            "func" => p.func,
            "timestamp" => string(p.timestamp),
            "input_fingerprint" => p.input_fingerprint,
            "package_version" => p.package_version,
            "statement_kind" => string(p.statement_kind),
            "notes" => p.notes,
        ) for p in r.provenance],
    )
end

function markdown_report(r::QualityReport)
    io = IOBuffer()
    println(io, "# AssaySentinel analytical report")
    println(io)
    println(io, "> ", SAFETY_NOTICE)
    println(io)
    println(io, "| Field | Value |")
    println(io, "| --- | --- |")
    println(io, "| Analyte | ", r.analyte, " |")
    println(io, "| Unit | ", r.unit, " |")
    println(io, "| Status | ", _status_label(r.status), " |")
    println(io, "| Sentinel Score | ", round(r.score.value; digits = 1), " |")
    println(io, "| n | ", r.n, " |")
    println(io, "| Package | AssaySentinel.jl ", PACKAGE_VERSION, " |")
    println(io)
    if r.reconstruction !== nothing
        rec = r.reconstruction
        println(io, "## Reconstruction")
        println(io)
        println(io, "```")
        println(io, rec.narrative)
        println(io, "```")
        println(io)
        if rec.rng_seed !== nothing
            println(io, "Reproducibility: `rng_seed=", rec.rng_seed,
                    "`  fingerprint=`", rec.input_fingerprint, "`")
        else
            println(io, "Fingerprint: `", rec.input_fingerprint, "`")
        end
        println(io)
        println(io, "## Uncertainty budget")
        println(io)
        ub = rec.uncertainty
        println(io, "| Quantity | Value |")
        println(io, "| --- | --- |")
        println(io, "| n with uncertainty | ", ub.n_with_uncertainty, " |")
        println(io, "| RMS(u) | ", ub.rms_measurement === nothing ? "—" : ub.rms_measurement, " |")
        println(io, "| analytical SD | ", ub.analytical_sd, " |")
        println(io, "| combined SD | ", ub.combined_sd, " |")
        println(io, "| weighted mean | ", ub.weighted_mean === nothing ? "—" : ub.weighted_mean, " |")
        println(io, "| magnitude SE | ", ub.magnitude_se, " |")
        println(io)
        println(io, ub.notes)
        println(io)
    end
    println(io, "## Findings")
    for e in r.evidence
        println(io, "- ", e)
    end
    println(io)
    println(io, "## Methods")
    println(io, "- Change-point: `", r.change_points.method, "` — ", r.change_points.selection_reason)
    println(io, "- Drift: `", r.drift.detector, "` / `", r.drift.kind, "`")
    if r.distribution !== nothing
        println(io, "- Distribution: `", r.distribution.method, "` — ", r.distribution.selection_reason)
    end
    println(io)
    println(io, "## Score components")
    println(io, "| Component | Penalty | Weight |")
    println(io, "| --- | --- | --- |")
    for k in keys(r.score.components)
        println(io, "| ", k, " | ", round(getfield(r.score.components, k); digits = 3),
                " | ", getfield(r.score.weights, k), " |")
    end
    println(io)
    println(io, "## Provenance")
    for line in provenance_lines(r.provenance)
        println(io, "- ", line)
    end
    println(io)
    println(io, "## Limitations")
    for L in r.limitations
        println(io, "- ", L)
    end
    println(io)
    println(io, "## Auditability")
    println(io, "Statements are tagged as observed fact, statistical result, algorithmic inference, or annotation.")
    String(take!(io))
end

function html_report(r::QualityReport)
    md = markdown_report(r)
    body = _md_to_html(md)
    figs = ""
    if r.reconstruction !== nothing
        c = r.reconstruction.charts
        extra = ""
        hasproperty(c, :lots) && !isempty(c.lots) && (extra *= "<figure>$(c.lots)</figure>\n")
        hasproperty(c, :instruments) && !isempty(c.instruments) && (extra *= "<figure>$(c.instruments)</figure>\n")
        figs = """
        <h2>Charts</h2>
        <figure>$(c.timeline)</figure>
        <figure>$(c.control_chart)</figure>
        $extra
        <figure>$(c.provenance)</figure>
        """
    end
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8"/>
    <title>AssaySentinel report — $(r.analyte)</title>
    <style>
      body { font-family: "Iowan Old Style", Georgia, serif; background:#f4f1ea; color:#1b2838; margin:2rem auto; max-width:860px; }
      h1,h2 { font-family: "Avenir Next", "Segoe UI", sans-serif; color:#1b2838; }
      blockquote { border-left:4px solid #c9892a; padding-left:1rem; color:#2c3338; }
      table { border-collapse: collapse; width:100%; }
      th,td { border:1px solid #c5c0b5; padding:0.4rem 0.6rem; text-align:left; }
      th { background:#2f7a78; color:#f4f1ea; }
      code { background:#e7e2d6; padding:0.1rem 0.3rem; }
      pre { background:#e7e2d6; padding:0.8rem 1rem; overflow-x:auto; }
      figure { margin:1.2rem 0; }
      figure svg { width:100%; height:auto; display:block; }
    </style>
    </head>
    <body>
    $body
    $figs
    </html>
    """
end

function _md_to_html(md::AbstractString)
    io = IOBuffer()
    in_table = false
    in_pre = false
    for line in split(md, '\n')
        if startswith(line, "```")
            if in_table
                println(io, "</table>")
                in_table = false
            end
            if in_pre
                println(io, "</pre>")
                in_pre = false
            else
                println(io, "<pre>")
                in_pre = true
            end
            continue
        end
        if in_pre
            println(io, _esc(line))
            continue
        end
        if startswith(line, "# ")
            println(io, "<h1>", _esc(line[3:end]), "</h1>")
        elseif startswith(line, "## ")
            println(io, "<h2>", _esc(line[4:end]), "</h2>")
        elseif startswith(line, "> ")
            println(io, "<blockquote>", _esc(line[3:end]), "</blockquote>")
        elseif startswith(line, "| ")
            if !in_table
                println(io, "<table>")
                in_table = true
            end
            cells = split(strip(line, '|'), '|')
            if all(occursin(r"^[\s:-]+$", c) for c in cells)
                continue
            end
            tag = occursin("Field", line) || occursin("Component", line) || occursin("Quantity", line) ? "th" : "td"
            print(io, "<tr>")
            for c in cells
                print(io, "<", tag, ">", _esc(strip(c)), "</", tag, ">")
            end
            println(io, "</tr>")
        else
            if in_table
                println(io, "</table>")
                in_table = false
            end
            if startswith(line, "- ")
                println(io, "<li>", _esc(line[3:end]), "</li>")
            elseif !isempty(strip(line))
                println(io, "<p>", _esc(line), "</p>")
            end
        end
    end
    in_table && println(io, "</table>")
    in_pre && println(io, "</pre>")
    String(take!(io))
end

_esc(s) = replace(replace(replace(s, "&" => "&amp;"), "<" => "&lt;"), ">" => "&gt;")
