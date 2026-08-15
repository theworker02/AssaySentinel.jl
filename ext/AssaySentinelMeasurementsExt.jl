module AssaySentinelMeasurementsExt

using AssaySentinel
using Measurements

function AssaySentinel.Measurement(m::Measurements.Measurement; kwargs...)
    AssaySentinel.Measurement{Float64}(;
        value = Measurements.value(m),
        uncertainty = Measurements.uncertainty(m),
        kwargs...,
    )
end

end
