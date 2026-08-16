using Documenter
using DocumenterCitations
using AssaySentinel

function _stage_docs_media()
    srcdir = joinpath(@__DIR__, "..", "assets")
    dstdir = joinpath(@__DIR__, "src", "assets")
    mkpath(dstdir)
    for name in (
        "demo.gif",
        "how-it-works.svg",
        "screenshot-reconstruction.png",
        "screenshot-report.png",
        "screenshot-control-chart.png",
        "logo-dark.svg",
    )
        src = joinpath(srcdir, name)
        isfile(src) && cp(src, joinpath(dstdir, name); force = true)
    end
    favicon_src = joinpath(srcdir, "icon.png")
    isfile(favicon_src) && cp(favicon_src, joinpath(dstdir, "favicon.png"); force = true)
    return nothing
end

_stage_docs_media()

bib = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"); style = :authoryear)

makedocs(;
    sitename = "AssaySentinel.jl",
    authors = "theworker02",
    modules = [AssaySentinel],
    repo = Documenter.Remotes.GitHub("theworker02", "AssaySentinel.jl"),
    format = Documenter.HTML(;
        prettyurls = !("local" in ARGS),
        canonical = "https://theworker02.github.io/AssaySentinel.jl",
        edit_link = "main",
        assets = ["assets/theme.css"],
        collapselevel = 1,
        ansicolor = true,
        footer = "AssaySentinel.jl is not a diagnostic medical device.",
    ),
    pages = [
        "Home" => "index.md",
        "Quickstart" => "quickstart.md",
        "Guide" => [
            "Measurements" => "measurements.md",
            "Assays" => "assays.md",
            "Quality control" => "qc.md",
            "Drift and change points" => "drift.md",
            "Batch effects" => "batches.md",
            "Calibration" => "calibration.md",
            "Reference intervals" => "reference.md",
            "Method comparison" => "comparison.md",
            "Streaming" => "streaming.md",
            "Simulation" => "simulation.md",
            "Provenance and reports" => "provenance.md",
        ],
        "Extensions" => "extensions.md",
        "Examples" => "examples.md",
        "API" => "api.md",
        "Methods" => [
            "Statistical methods" => "statistical_methods.md",
            "Validation" => "validation.md",
            "References" => "references.md",
        ],
    ],
    plugins = [bib],
    checkdocs = :exports,
    warnonly = [:missing_docs],
)

# GitHub Pages is configured as a workflow deploy (`docs/build` artifact).
# `deploydocs` is optional and only used when a Documenter SSH key is present.
if !isempty(get(ENV, "DOCUMENTER_KEY", ""))
    deploydocs(;
        repo = "github.com/theworker02/AssaySentinel.jl.git",
        devbranch = "main",
        push_preview = true,
    )
end
