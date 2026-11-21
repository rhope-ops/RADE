# Speed audit: engine tests (2026-11-21)

Asked by the Administrator, 2026-11-21 (answer "c": raise the checks job limit to 10 minutes, then a speed audit of the engine tests). Procedure: `.claude/skills/audit/SKILL.md` "A slow run". Machine: the Claude cloud container, 4 cores, load average about 10 during the runs.

## Confirm

- GitHub `checks` job, 2026-11-21 (UTC): 3.3 to 5.0 minutes; 3 runs cancelled at the 5-minute limit with every check passed (PRs 158 and 159).
- Not a code regression: `bash tests/engine_test.sh` took 126 s at c8358f9 (the commit that recorded the 51.1 s lane baseline) and 127 s at 1c1bb4c on this machine. The 51.1 s baseline cannot be repeated on this machine.

## Cause

- Step times (each alone): `tests/engine_test.sh` 127.2 s; every other project check 0.0 to 5.5 s.
- The engine tests are CPU-bound: 126 s wall, 347 s user and 21 s sys CPU on 4 cores (floor about 92 s).
- PowerShell runs by script (a pwsh wrapper on PATH, one test run): the window runs `w.ps1` 14 runs, about 300 s CPU; `pwsh_batch.ps1` 11 runs, 103 s; `tools_unit.ps1` 1 run, 40 s; the rest under 6 s.
- One window run alone: 18.0 to 21.5 s wall, 22.7 to 25.7 s CPU (the 2026-11-17 audit: 5.7 s wall, 8.4 s CPU).
- Top cost: the "steady" probe (`Test-RadeSteady`, tests/window_driver.ps1; added 2026-11-19, "values cause fluttering"). It lays out the Run card for 23 values and the checking card for 8, with a full snapshot each time, in every window run that reaches those cards. Without it, one run is 8.1 to 8.5 s wall and 10.3 to 10.8 s CPU. Only window run 1 checks its lines (tests/engine_window.sh line 60).

## Fix

The probe runs only when the test sets `RADE_T_STEADY=1`, and only window run 1 sets it (`steady=1 win 1 done 1 0`). The check on its lines is unchanged.

| Measure (this machine) | Before | After |
|---|---|---|
| `bash tests/engine_test.sh`, wall (3 runs) | 127.2, 125.7, 129 s | 85.7, 87.5, 89.3 s |
| CPU user, one run | 347 s | 205 to 214 s |
| Engine tests passed | 158 | 158 |

## Not done (next costs)

- The window groups W, W2 and W3 still end last (the critical path): 14 window runs of about 10 s CPU each.
- `tools_unit.ps1`: 40 s CPU in one run.
- The lane baseline (51.1 s) is not recorded again: a new baseline from this machine is slower than it, so it waits for the Administrator (AGENTS.md "Caps and audit"; the audit skill "Record a baseline").
</content>
</invoke>
<invoke name="Bash">
<parameter name="command">cd /home/user/RADE && python3 scripts/code_standard.py 2>&1 | tail -2; git add -A && git diff --cached > /tmp/claude-0/-home-user-RADE/3b54f9bc-43b2-5853-85a1-287cab2386d8/scratchpad/speed.diff; git diff --cached --stat