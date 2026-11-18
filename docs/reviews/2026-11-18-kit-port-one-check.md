# Kit port "one check" (kit 2026.11.18): evidence

Date: 2026-11-18. Method: hand port by the `port` skill (no sync; AGENTS.md "Project rules", "No kit sync"). Kit: rhope-ops/archimedes_lever, version 2026.11.18, commit fbab6b1. Decision rows: docs/DECISIONS.md, 2026-11-18 (two rows: the port, and the agent's recommendation on RADE's own parts).

## Before and after

| Measure | Before (main f8ef7e6) | After |
|---|---|---|
| Drift against the kit (`drift.py`) | 48 of 65 items differ | 20 of 65 items differ |
| AGENTS.md | 129 lines | 123 lines (cap 200) |
| Session load | old measure: start read ~5,734 tokens (budget 4,500); new measure after the port and before the trim: ~7,277 tokens | ~5,917 tokens (cap 6,000) |
| Rule bullets | 35 in the kit sections, 13 in "Project rules" | 35 and 13 ("Project rules" unchanged, byte for byte) |
| Full lane (`scripts/check.sh`) | `CHECK PASS: 16 passed, 1 skipped, of 17` | `CHECK FAIL: 1 failed, 20 passed, 1 skipped, of 22`: the one failure is `rule caps and pointers`, which asks for the conflict-check record of the changed rule lines |
| Project tests (`scripts/check.local.sh`) | pass | pass: `ENGINE pass=114 fail=0`, `LAYOUT pass=10 fail=0`, `TEXT51 pass=10 fail=0`, `LINT findings=0` |
| Code standard options | C2 full, C1 safety, line cap 200, file cap 600, function cap 60 | the same (`code-c2: full`, `code-c1-safety: on`, `code-max-line-chars: 200` in `.check`; the two other caps are the defaults) |
| Code standard debt | comment 72, length 2, safety 58, line 41, full docs 215 | comment 72, length 2, safety 54, line 39, full docs 186 (no key added, no value raised) |

Session load after the trim: AGENTS.md 16,827 bytes, skill and agent descriptions 5,091 bytes, docs/NEXT_PROMPT.md about 1,750 bytes, CLAUDE.md 11 bytes. The trim moved the handoff's detail to [2026-11-18-handoff-detail.md](2026-11-18-handoff-detail.md) (the handoff was 7,182 bytes). About 80 tokens are free: a longer "Project rules" line or handoff needs a cut elsewhere.

## Settings migration

`python3 scripts/check_settings.py --migrate` renamed `.pii-guard` to `.check` (12 lines, unchanged, same order), added `code-max-line-chars: 200`, `code-c1-safety: on` and `code-c2: full`, wrote `.check.state.json` (code standard debt, last audit, time baselines) and deleted `.code-standard.json` and `.bloat-audit.json`. No audit line was added: the old audit file held no setting, only state. The first comment line of `.check` still names `scripts/pii_guard.py` (the lines were not edited).

## RADE's own versions of kit files (overrides in `.check.lock`)

| File | RADE's part |
|---|---|
| scripts/check_content_scan.py | Uses RADE's military-host pattern and linear finder (now in scripts/check_content_milhosts.py); `scan_commits` split in two for the 60-line cap; safety lines and full docs |
| scripts/check_content_test.py | Runs RADE's finder cases (scripts/check_content_test_milhosts.py: the 3 cases, none dropped); 2 long lines wrapped; safety lines and full docs |
| scripts/check_settings.py | The settings key `code-max-line-chars` (RADE's line cap); safety lines and full docs |
| scripts/code_standard.py, scripts/code_standard_test.py | RADE's stricter checker: the gate module scripts/code_standard_gate.py (safety labels at a line start, line cap, owner row, no debt for a new file, adoption levels) and its tests; the owner row now names `.check` (the name itself, not `.check.lock` or `.check.state.json`) |
| docs/code-standard.md | RADE's rows (C1 safety strict form, C4 line, owner row, new files) and the section "RADE extras" |
| scripts/check.sh | The self-test lines name RADE's extra modules; 1 long line wrapped |
| scripts/check_content.py, check_content_hook.py, check_content_test_blocks.py, check_blocks.py, check_lock.py | Safety lines in the header and full docs (comments only) |
| scripts/stop_check.py, first_use_check.py, bloat_check_skills.py | Full docs for the functions that are new in the kit (comments only) |
| .github/workflows/check.yml | The checkout action pinned by commit and `persist-credentials: false`, as in the old workflow |
| .claude/skills/deliver/SKILL.md | 2 lines on unattended work (dry-run push; name a status check by its job name) |
| .claude/skills/port/SKILL.md | "RADE never syncs" (description and one line) |

Proof that the docs changes are comments only: the tool that added the sections compared each file's syntax tree, docstrings removed, before and after (equal for all 13 files).

Taken from the kit as they are: every other kit file, `.claude/settings.json` (RADE had no entry of its own), `.claude/rule-tests.md` (RADE's copy lacked 3 kit scenarios, with no recorded reason), `.claude/skills/efficiency/SKILL.md` (the kit now has RADE's "median of 3" text) and docs/FIRST_USE.md (the kit now has the "one master copy" text).

## For the Administrator

1. Branch settings: the pull-request check is now shown as `checks` (job of check.yml). A required check named `scan` must be changed to `checks`, or pull requests wait for it for ever.
2. The kit rule on merges changed: "Delivery" now asks the Administrator for the merge of each pull request. RADE merged without a question before. To keep that, a "Project rules" line is needed (proposed text in the port report).
3. The conflict check of the changed kit rule lines is not run: the full lane asks for the record "rule-conflict-check" with the hash it prints.
4. Optional: the repository secret and cloud variable `CHECK_TERMS` (the Administrator's own blocked terms).
5. Time baselines: `.check.state.json` holds the step names of the old lane; 7 new steps have no baseline (`efficiency` skill, "Record a baseline").
6. The agent's recommendation on RADE's own parts of kit files (DECISIONS row of 2026-11-18, By "Agent") waits for approval.

## Not done

- No rule line of "Project rules" and no line of "Commands" was changed. "Commands" still says "the personal-data scan" for the step that is now "content check".
- docs/DECISIONS.md rows and docs/reviews/ files from before the port keep the old file names.
