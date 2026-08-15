using Documenter
using DocumenterCitations
using AssaySentinel

bib = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"); style = :authoryear)

makedocs(;
    sitename = "AssaySentinel.jl",
    authors = "theworker02",
    modules = [AssaySentinel],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://theworker02.github.io/AssaySentinel.jl",
        assets = ["assets/logo.svg"],
        footer = "AssaySentinel.jl is not a diagnostic medical device.",
    ),
    pages = [
        "Introduction" => "index.md",
        "Quickstart" => "quickstart.md",
        "Measurements" => "measurements.md",
        "Assays" => "assays.md",
        "QC" => "qc.md",
        "Drift Detection" => "drift.md",
        "Batch Effects" => "batches.md",
        "Calibration" => "calibration.md",
        "Reference Intervals" => "reference.md",
        "Method Comparison" => "comparison.md",
        "Streaming" => "streaming.md",
        "Extensions" => "extensions.md",
        "Simulation" => "simulation.md",
        "Provenance" => "provenance.md",
        "API" => "api.md",
        "Statistical Methods" => "statistical_methods.md",
        "Validation" => "validation.md",
        "Examples" => "examples.md",
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
