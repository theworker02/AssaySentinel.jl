# Live Documenter site.
#
#   julia --project=docs docs/live.jl
#
# Rebuilds on save and serves at HOST:PORT (default 127.0.0.1:8000).
# Bind HOST=0.0.0.0 and PORT from the environment when running as a service.

using Pkg
Pkg.instantiate()

using LiveServer

host = get(ENV, "HOST", "127.0.0.1")
port = parse(Int, get(ENV, "PORT", "8000"))

println("AssaySentinel live docs at http://", host, ":", port)
servedocs(;
    foldername = @__DIR__,
    doc_env = true,
    host,
    port,
    launch_browser = get(ENV, "DOCS_BROWSER", "true") == "true",
)
