# Method and instrument comparison

```julia
compare_methods(methodA, methodB; method=:ba)
compare_instruments(a, b; method=:passing_bablok)
compare_lots(data, :lot)
compare_sites(data; site=:site)
```

| Method | Reference |
| --- | --- |
| `:ba` | Bland–Altman [bland1986](@cite) |
| `:passing_bablok` | Passing & Bablok [passing1983](@cite); slope and intercept 95% CIs in `details` |
| `:deming` | Errors-in-variables regression |
| `:robust` | Theil–Sen [theil1950](@cite) [sen1968](@cite) |

Lot comparison reports location (Kruskal–Wallis), variance (Brown–Forsythe
[brown1974](@cite)), and optional two-sample KS.
