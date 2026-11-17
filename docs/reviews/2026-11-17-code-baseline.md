# Code standard baseline: RADE, 2026-11-17

First measurement for docs/code-standard.md (the Administrator, 2026-11-17). Command: `python3 tests/check_code_standard.py --report` on commit ff92dc4 (main), 2026-11-17 (America/Chicago).

## Spread of function lengths (191 Python, shell and PowerShell functions; the engine's PowerShell is not counted yet because it is a Python string)

| Percentile | 50 | 75 | 90 | 95 | 99 |
|---|---|---|---|---|---|
| Lines | 7 | 19 | 40 | 59 | 90 |

The cap of 60 lines per function comes from the 95th percentile; the cap of 600 lines per file keeps a file readable in one sitting.

## Debt in the baseline (tests/code-standard-baseline.json)

| Rule | Items | Largest |
|---|---|---|
| C1 header | 0 (1 fixed in this change: the sample T04 script) | — |
| C2 comment | 135 functions | — |
| C3 length | 9 functions | scripts/pii_guard.py self_test 478 (kit), tests/window_driver.ps1 Pump 137, scripts/bloat_check.py self_test 193 (kit) |
| C4 file size | 4 files | engine/rade_build.py 2,986; scripts/pii_guard.py 1,218 (kit); scripts/bloat_check.py 825 (kit); tests/engine_test.sh 612 |
| C5 duplicate | 0 | — |

## The engine PowerShell (measured apart: lines 92-2736 of engine/rade_build.py, parsed by pwsh)

197 functions and named script blocks; 82 without a comment; 3 over 60 lines: Invoke-Round 162, Invoke-Check 145, Invoke-RoundStep 67. Next stage (approved plan): move it into engine/ps/*.ps1 so the check measures it, with every function commented and none over the cap.
