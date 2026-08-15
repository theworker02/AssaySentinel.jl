"""
    AbstractDetector

Generic detector API for research extensions.

```julia
fit!(detector, baseline)
update!(detector, measurement)
result(detector)
```
"""
abstract type AbstractDetector end

function fit! end
function result end

# Default no-op hooks so custom detectors only implement what they need.
fit!(d::AbstractDetector, ::Any) = d
result(::AbstractDetector) = nothing
