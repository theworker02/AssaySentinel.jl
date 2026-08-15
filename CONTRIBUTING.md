# Contributing to AssaySentinel

Thanks for helping build explainable analytical-quality software.

## Principles

1. Prefer published statistical methods over undocumented heuristics.
2. Separate **observed facts**, **statistical results**, **algorithmic inference**, and **annotations**.
3. Never add patient-diagnosis or treatment features.
4. Keep the core dependency set small. Optional integrations belong in `ext/`.
5. Do not silently convert units or impute missing values with zero.
6. Stochastic code must accept an `AbstractRNG`.
7. Cite the method in `STATISTICAL_METHODS.md` when you add an algorithm.

## Setup

```bash
julia --project -e "using Pkg; Pkg.instantiate()"
julia --project -e "using Pkg; Pkg.test()"
```

If `Pkg.test()` cannot resolve the registry locally, run the source-loaded suite:

```bash
julia --startup-file=no test/run_local.jl
```

Live documentation (rebuild on save):

```bash
julia --project=docs docs/live.jl
```

## Project layout

| Path | Purpose |
|------|---------|
| `src/` | Library |
| `ext/` | Optional Makie / Unitful / Measurements / Turing / OnlineStats |
| `test/` | Test suite |
| `examples/` | Demonstrations |
| `docs/` | Documenter site |
| `assets/` | Canonical SVG logos |
| `benchmark/` | Runtime / allocation harness |

## Pull requests

- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`
- Update `CHANGELOG.md` under `[Unreleased]`
- Add tests for statistical identities where possible
- Keep PRs focused

## Branding

- `assets/logo.svg` — canonical mark
- `assets/logo-dark.svg` / `assets/logo-light.svg`
- `assets/icon-256.png`, `assets/icon-512.png`, `assets/icon.png`
- `assets/social-preview.png` — 1280×640 GitHub social card
- Palette: navy `#1B2838`, teal `#2F7A78`, amber `#C9892A`, cream `#F4F1EA`
- Regenerate rasters with `python assets/generate_assets.py`

No medical crosses, hearts, stethoscopes, DNA-as-logo, or AI-brain imagery.

## Code of conduct

See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Security

See [`SECURITY.md`](SECURITY.md).
