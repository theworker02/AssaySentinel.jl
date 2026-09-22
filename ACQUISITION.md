# Acquisition Brief â€” AssaySentinel.jl

**Date:** 2026-09-22  
**Repository:** https://github.com/theworker02/AssaySentinel.jl  
**Default branch:** `main`  
**Primary language:** Julia  
**Status:** Diligence briefing only. **No acquisition has occurred** by virtue of this file.  
**License:** Proprietary â€” sale, written commercial license, or completed asset transfer required (see root `LICENSE`).  
**Valuation:** Not stated.  
**Contact:** GitHub [@theworker02](https://github.com/theworker02) Â· [thanks.dev/u/gh/theworker02](https://thanks.dev/u/gh/theworker02)

> Cloning or forking this repository does **not** grant production, redistribution, SaaS, OEM, or commercial rights.

---

## 1. Executive thesis

<img src="assets/logo.svg" alt="AssaySentinel" width="168"/> <strong>Know when the measurement changed<br/>before the science does.</strong> A Julia instrument for scientists and laboratory physicians who need to know<br/>

**Why a buyer cares:** AssaySentinel.jl packages transferable product IP â€” source, docs, in-repo brand assets, and a diligence room under `docs/acquisition/` â€” under a clear proprietary posture so diligence can proceed without mistaking the repo for open source.

---

## 2. Product snapshot

| Item | Detail |
|------|--------|
| Product | AssaySentinel.jl |
| Repo | `theworker02/AssaySentinel.jl` |
| Language | Julia |
| Open source? | **No** â€” proprietary |
| Rightsholder | theworker02 |
| Diligence pack | `docs/acquisition/` |

### Capability highlights (from current materials)

- **Scientists** running longitudinal assays, method studies, or multi-instrument programs
- **Assay developers** watching reagent lots, calibrators, and transfer protocols
- **Clinical laboratory researchers** investigating QC, bias, and process capability
- **Biostatisticians** who need dated change-points with an uncertainty budget
- **Physicians** doing measurement-quality, method-comparison, or laboratory research work
- [Published docs](https://theworker02.github.io/AssaySentinel.jl)
- [`STATISTICAL_METHODS.md`](STATISTICAL_METHODS.md) Ã¢â‚¬â€ estimators, penalties, and citations
- [`VALIDATION.md`](VALIDATION.md) Ã¢â‚¬â€ what has been checked, and what has not
- [`CHANGELOG.md`](CHANGELOG.md)

---

## 3. Problem / opportunity

Teams evaluating AssaySentinel.jl typically need either (a) a commercial right to run or embed it, or (b) outright ownership of the Product IP for strategic build-out. Public GitHub visibility without a proprietary license creates false assumptions about free production use. This brief and the linked data room make the commercial path explicit.

---

## 4. What ships today

Honest maturity: treat repository contents, README claims, tests, and release tags as the source of truth. Do not assume production customers, ARR, filed patents, or SLAs unless separately evidenced in diligence.

Typical transferable surfaces:

- Source tree and build/test scripts present in-repo
- Documentation and design notes
- Acquisition / diligence markdown under `docs/acquisition/`
- Branding assets committed to the repository (if any)

---

## 5. Demo / evaluation path (buyer)

Minimal path (no secrets required unless README says otherwise):

```
```julia
using AssaySentinel

data = showcase_dataset()
result = analyze(data.stream)
println(result)
explain(result)
report(result, "assay-report.html")
```
```julia
result = analyze(
    Assay(name = "Example Assay", analyte = :analyte_x, unit = "mg/dL"),
    table;
    value = :result,
    time = :timestamp,
    lot = :reagent_lot,
    instrument = :instrument,
)
```
```julia
srep = analyze(study, Dict("Lab-A" => stream_a, "Lab-B" => stream_b))
explain(srep)
report(srep, "study-report.html")  # forest plot + per-site charts
```
```julia
panel = AssayPanel("chem-14")
push!(panel, glucose_stream)
push!(panel, creatinine_stream)
prep = analyze(panel)
explain(prep)
report(prep, "panel-report.html")  # status chart + per-analyte control charts
```
```julia
using Pkg
Pkg.add(url="https://github.com/theworker02/AssaySentinel.jl")
```
```julia
using Pkg
Pkg.add("AssaySentinel")   # after General registration
```
```

Extended evaluation: `docs/acquisition/BUYER_EVALUATION.md`. Written NDA / evaluation grants may be required for private materials.

---

## 6. What a transaction typically includes

Subject to definitive schedules:

| Included (typical) | Excluded (typical) |
|--------------------|--------------------|
| Repo materials + asserted original IP | Seller personal accounts / unrelated repos |
| Docs + diligence room at closing | Third-party dependency source under separate licenses |
| In-repo brand marks as assigned | Secrets without rotation plan |
| Know-how captured in docs | Fabricated revenue, user, or adoption metrics |

---

## 7. Suggested deal structures

| Structure | When it fits |
|-----------|--------------|
| Non-exclusive commercial license | Deploy/run under seat or environment terms |
| Exclusive field-of-use license | Buyer wants exclusivity; seller may retain entity |
| Asset / IP assignment | Buyer wants ownership of Materials outright |
| OEM / redistribution | Separate agreement â€” not implied here |

Commercial terms (price, earnouts, escrow) are negotiated under NDA with counsel.

---

## 8. Buyer diligence checklist

- [ ] Confirm Rightsholder identity and authority to sell/license
- [ ] Inventory Materials (`docs/acquisition/ASSET_INVENTORY.md`)
- [ ] Review IP posture (`IP_PROVENANCE.md`) and dependencies (`DEPENDENCY_INVENTORY.md`)
- [ ] Run evaluation script (`BUYER_EVALUATION.md`)
- [ ] Review risks (`RISK_REGISTER.md`)
- [ ] Agree transfer scope (`TRANSFER_MANIFEST.md`) and handoff (`HANDOFF_CHECKLIST.md`)
- [ ] Supersede root `LICENSE` at closing via definitive agreement

---

## 9. Related documents

| Document | Purpose |
|----------|---------|
| `LICENSE` | Proprietary â€” no default grant |
| `docs/acquisition/README.md` | Data-room index |
| `docs/acquisition/EXECUTIVE_SUMMARY.md` | One-page thesis |
| `README.md` | Product overview |
| `SECURITY.md` | Vulnerability reporting |
| `COMMERCIAL.md` | Licensing contact path |
| `.github/FUNDING.yml` | Sponsors / thanks.dev |

---

## 10. Disclaimer

This package is informational and **does not** create a binding offer, grant of rights, or investment advice. Engage counsel for any transaction.

---

*Document version: 2.0.0 / 2026-09-22 Â· Classification: acquisition briefing*
