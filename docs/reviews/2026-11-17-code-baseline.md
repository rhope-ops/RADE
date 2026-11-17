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
| C2 comment | 160 functions (after the two review fixes: a header, divider or next-line comment no longer counts) | — |
| C3 length | 10 functions (with .claude/skills/ui-verify/measure.mjs, checked from the review fix) | scripts/pii_guard.py self_test 478 (kit), tests/window_driver.ps1 Pump 137, scripts/bloat_check.py self_test 193 (kit) |
| C4 file size | 4 files | engine/rade_build.py 2,986; scripts/pii_guard.py 1,218 (kit); scripts/bloat_check.py 825 (kit); tests/engine_test.sh 612 |
| C5 duplicate | 0 | — |

## The engine PowerShell (measured apart: lines 92-2736 of engine/rade_build.py, parsed by pwsh)

197 functions and named script blocks; 82 without a comment; 3 over 60 lines: Invoke-Round 162, Invoke-Check 145, Invoke-RoundStep 67. Next stage (approved plan): move it into engine/ps/*.ps1 so the check measures it, with every function commented and none over the cap.

Review fix (fresh review of pull request 79, same day): the baseline is also compared with main, shell `${#..}` is measured right, PowerShell parse errors fail (C10), files with no extension and a shell or Python shebang and `.mjs` files are checked, and long script blocks passed to a call count for C3. The baseline was written again before it reached main.
Second review fix (same day): shell `function name {` and a brace on the next line are found; a comment after a one-line function or a file help header no longer counts; a Python lead comment counts; an arrow with no braces is not a function; docstring-only copies are duplicates. The baseline was written again before it reached main.
