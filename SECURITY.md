# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.5.x | Yes |
| 1.4.x | Yes |
| 1.3.x | Yes |
| 0.1.x | Security fixes only |

## Reporting

Please report vulnerabilities privately via GitHub Security Advisories on
[theworker02/AssaySentinel.jl](https://github.com/theworker02/AssaySentinel.jl).

Do not open a public issue for exploitable defects.

## Data handling

AssaySentinel is a local library. It does not phone home. Do not commit
measurement files that contain patient identifiers. Prefer synthetic streams
from `simulate_assay` / `showcase_dataset` in reproductions.

## Scope

AssaySentinel is research software for analytical quality. It is not a
diagnostic device and must not be treated as one in security or regulatory
assessments.
