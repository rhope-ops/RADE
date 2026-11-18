# Test speed audit: 2026-11-17 (America/Chicago)

Asked for by the Administrator ("run the audit on RADE's tests"): the full lane (`scripts/check.sh`) took about 100 s
against its recorded baseline of 45.7 s (`.bloat-audit.json` "timings", commit de57524, 2026-11-16). Scope: the tests
(audit categories 5 and 6: slow and serial steps). Base: 7cd531b (main). Machine: cloud container, 4 cores, pwsh 7.4.6,
Python 3. Every time below is the median of 3 runs on an idle machine unless it says otherwise.

## Before and after

| Measure | Before (7cd531b) | After (S1+S2+S3) | Commits |
|---|---|---|---|
| `bash tests/engine_test.sh` | 85.7 s (85.7, 84.8, 86.8) | 50.4 s (50.4, 51.8, 49.6) | S1 → 58.8 s, S2 → 53.6 s, S3 → 50.4 s |
| `scripts/check.sh` (full lane) | 99.8 s (100.6, 99.8, 99.1); CHECK PASS | 64.1 s (63.4, 64.1, 65.5); CHECK PASS | same |
| ENGINE result | pass=108 fail=0 | pass=108 fail=0 | each commit |
| Sorted PASS/FAIL names (108) | list A | identical to A after S1, S2 and S3 | `diff` empty |
| Critical path | group W, 86.9 s of a 90.7 s profiled run | all groups end within 2 s of each other | |
| CPU of one run (whole machine, /proc/stat) | not measured | 203 s busy, 8 s idle in 53 s (after S2) | |
| Code-standard baseline | engine_test.sh 612 lines (C4 debt), `win` comment debt | both fixed, baseline lowered (shrink only) | S1 |

The full lane is still over the old baseline (+40 %, so check.sh keeps its WARN). See "For the Administrator".

## How it was measured

- Profile: `PS4='+${EPOCHREALTIME} ${BASHPID} ${LINENO} '` with `set -x` to a file (BASH_XTRACEFD), then the first and last
  trace line of each process (each background group) and the time between trace lines of the main shell.
- Process counts: `strace -f -e trace=execve` over one run.
- One window run: the same bundle and driver run alone with `time`; inside it, a copy with a timestamp line before every
  statement (PowerShell AST), self time added up by line and by engine part.
- PASS names: engine_test.sh prints only FAIL lines and the count, so a scratch copy (not committed) made `ok` print
  `PASS <the message of the bad call on that line>`; the sorted lists before and after were compared with `diff`.
- Window runs: each run's output (win.txt) was saved before and after S1 and compared after masking temp paths, dates and
  durations.

## Top 3 costs (before)

1. **Group W: 12 window runs in one chain.** It started at 3.8 s and ended at 90.6 s of a 90.7 s run; every other group
   had ended by 48.2 s. Alone, the chain took 75.8 s (runs of 3.8 to 8.0 s, median 5.7 s; about 8.4 s of CPU each, as
   PowerShell runs the window logic: the cost is spread over the engine parts, window/01-setup.ps1 the largest at 20 %).
2. **pwsh process starts: 133 per run.** 81 are the engine's own child processes (each step and some checks run as
   `pwsh -NoProfile -ExecutionPolicy Bypass -File ...`, the product's design); 26 are started by the test (12 window
   runs, the batch runners of the main shell and the groups, and single checks such as the site rule and the progress test). A bare start costs about 0.31 s of CPU and 0.24 s of wall time.
   Each window run also compiled the stand-in types (tests/window_stub.cs) with Add-Type: about 0.85 s of CPU, 12 times.
3. **The serial text-mode part of the main shell: 17.7 s** before the marker groups (MA, MC, MD, MG) and the cross-version
   group (X) could start, 11.9 s of it waiting for text-mode rounds; MA then ran to 48.2 s.

Not a cost: the engine builds (29 runs of `python3 engine/rade_build.py` per test run, about 0.05 s each).

## Cause of the growth

At the baseline (de57524, 2026-11-16) the test had 5 window runs and took 43.1 s (median of 3, measured on this machine
from `git archive de57524`); group W was 38.2 s. 7cd531b has 12 window runs. All 7 added runs are from 2026-11-17 and run
in the same serial chain, about 6 s each (about +42 s on the critical path):

| Window run added | Commit |
|---|---|
| 2b Start (`start=1`) | d229ae6 Start button, installed runner copy and desktop shortcut |
| 2b2 Start on Maintenance (`start=maint`) | 17c7f62 R28 engine fixes (engine-v10) |
| 2c boot error, no application, Cancel (3 runs) | 87e6933 States and text: Cancel, boot-error and no-application cards |
| 6 window place (2 runs) | f7fc63d Window size and place |

The text-mode runs did not grow (42 `round`/`psrun`/`mkround`/`xrun` calls at both commits). The checks grew from 93 to 108.

## Changes made (one commit each, each can be taken or dropped alone)

### S1: the window runs in 3 parallel groups (6c0d422)

- What: the window section moves to tests/engine_window.sh (sourced by engine_test.sh: engine_test.sh had grown past the
  600-line limit of docs/code-standard.md C4, and S1 would have made it longer) and runs as groups W, W2 and W3, each with
  its own folder (users root, bundle copies, win.txt). W keeps runs 1, 2, 2b, 2b2 and Cancel in their old order on one
  users root. W2 (boot error, no application, test round, failed download) and W3 (scale 150 %, shortcut folder, window
  place) start from a copy of the users root as run 1 left it (an installed app).
- Saving: 85.7 s → 58.8 s (−26.9 s, −31 %).
- Proof that the tests are the same: the 108 PASS names are identical; all 12 runs show the same card sequence (every
  `WIN view=` line). The Cancel run first showed a different plan from a fresh copy (4 steps instead of 2), so it stays in
  W, where it has the same state as before. Remaining differences: time estimates, the order of the "made" list (it
  already varies from run to run), and 1 list instead of 2 in the made list of the W3 runs (no test reads it).
- Risk: low. A future window run that needs the state of an earlier run must go in the same group (the comment at `wgo`
  says what each group starts from). Files: tests/engine_test.sh, tests/engine_window.sh (new), tests/window_driver.ps1
  and tests/window_stub.cs (header pointers), tests/code-standard-baseline.json (lowered).

### S2: the groups that use only their own folders start first (3661342)

- What: the marker groups (MA, MC, MD, MG) and the cross-version group (X) start right after the first build, with the
  window groups, so they run beside the serial text-mode part. The marker app was copied after the text-mode deploys had
  moved every `"version": "1.0.0"` to 1.2.0; its build now makes the same change, so its manifest and built bundle are
  byte for byte the same as before (`cmp` of both files, old and new layout).
- Saving: 58.8 s → 53.6 s (−5.2 s).
- Risk: low; a later change to the text-mode part no longer reaches the marker app (the comment says so). File:
  tests/engine_test.sh.

### S3: the stand-in types are compiled once (e619f74)

- What: group W compiles tests/window_stub.cs once into a DLL (the driver with `RADE_T_STUB_OUT`: compile and stop); every
  window run loads that DLL. Without the DLL a run compiles the source, as before. Measured alone: Add-Type from source
  0.75–0.86 s wall and about 1.35 s CPU; from the DLL 0.33–0.38 s and about 0.45 s.
- Saving: 53.6 s → 50.4 s (−3.2 s; user CPU 1m46s → 1m38s).
- Risk: low (the same source and references). Files: tests/window_driver.ps1, tests/engine_window.sh.

## Proposals not made

| # | Proposal | Saving | Risk | Why not made |
|---|---|---|---|---|
| S4 (made later: the Administrator took it on 2026-11-18, commit 475ee83) | scripts/check.local.sh: start `tests/engine_test.sh` in the background before the other project checks (code-standard self-test 5.0 s, lint 4.4 s, app canary 1.8 s, code standard 1.3 s, bundle layout 0.5 s run serially after it now) and wait for it at its place | check.local.sh 65.5 s → 58.1 s (−7.4 s, measured with a scratch copy, 3 runs each) | low: the output order of check.local.sh changes; the fast lane keeps its `changed` condition | check.local.sh is run by the pre-push hook, so it is a guard file (AGENTS.md "Rules and decisions"): it changes only on the Administrator's request |
| S5 | Run the window cases in one pwsh process (like tests/pwsh_batch.ps1 for text mode) | about 0.3–0.6 s CPU per run, about 2 s wall | medium: the stand-in types keep static state (pump count, timers, focus, screens) that would need a reset between runs | small gain now that the machine is busy on all 4 cores |
| S6 | Make the window logic cheaper in the engine (for example fewer script-block calls for sizes: `$ui.Sc` 1,220 calls and `$ui.WordW` 4,245 calls in one run) | unknown; window runs are about half of the 203 s of CPU | engine change: it ships to work computers (Windows PowerShell 5.1) | outside a test audit: an engine change for the Administrator to decide |
| — | Fewer engine child processes (81 per run) | large | it changes what is tested (steps run as their own process in the product) | not a test change |
| — | .NET settings for short pwsh runs (`DOTNET_TieredPGO=0`, `DOTNET_TieredCompilation=0`, `DOTNET_TC_QuickJitForLoops`, `DOTNET_GCgen0size`) | 0 to 5 % of one window run, inside the noise | none | measured, not worth it |

## What did not change

- No test was removed, skipped or weakened; every `has`, `grep` and `ok`/`bad` line is the same text (S1 moved lines into
  tests/engine_window.sh and changed only `$t/win.txt` → `$wd/win.txt` and `$t/wu` → `$wd/u`).
- No change to the engine, AGENTS.md, .claude/, scripts/git-hooks/ or workflows. scripts/check.local.sh changed only
  for S4, after the Administrator took it (2026-11-18).
- `.bloat-audit.json` is not changed: the timing baseline is for the Administrator (below).

## For the Administrator

1. Which commits to take: S1, S2 and S3 are independent of each other in effect but S2 and S3 are written on top of S1
   (the same files). REC: take all three.
2. S4 (scripts/check.local.sh, a guard file): measured −7.4 s. REC: approve it as a follow-up; the full lane would then be
   about 57 s.
3. The timing baseline: even with S1–S4 the full lane (about 57–64 s) stays over 45.7 s +25 % (57.1 s), because the 7
   window runs added on 2026-11-17 cost CPU, and the machine is now busy on all 4 cores. Recording a slower baseline
   with no further fix needs the Administrator's approval (`.claude/skills/efficiency/SKILL.md` "Record a baseline").
   REC: after the commits merge, record the median of 3 full-lane runs as the new baseline.
