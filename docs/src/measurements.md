# Measurements

`Measurement` is the atomic observation. Keyword `lot` aliases `reagent_lot`.

```julia
Measurement(
    value = 101.2,
    uncertainty = 0.4,
    unit = "mg/dL",
    timestamp = now(),
    batch = "B104",
    instrument = "Analyzer-A",
    lot = "R22",
    control = true,
)
```

Missing and `NaN` stay missing. They are never coerced to zero.

## Units

`check_units` refuses to compare `mg/dL` with `mmol/L`. Convert explicitly:

```julia
convert_unit(90.0, "mg/dL", "mmol/L"; molar_mass=180.156)
```

Optional [Unitful.jl](https://github.com/PainterQubits/Unitful.jl) support is a
package extension.

## Uncertainty

Store a numeric `uncertainty` on each measurement. Optional
[Measurements.jl](https://github.com/JuliaPhysics/Measurements.jl) values can
be passed to the `Measurement` constructor when that extension is loaded.
