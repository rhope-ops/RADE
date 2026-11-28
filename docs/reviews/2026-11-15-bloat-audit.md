# Bloat audit: 2026-11-15 (America/Chicago)

First full audit (`.claude/bloat-audit.md`), asked for by the Administrator on 2026-11-15. Base: main 67f7681. Machine: cloud container, 4 vCPU Intel Xeon 2.10 GHz (times compare only on this kind of machine). Agent time: about 1 hour.

Scope limit: engine/rade_build.py, tests/, docs/window-design.md, docs/NEXT_PROMPT.md item 11 and schemas/ change in [pull request 55](https://github.com/rhope-ops/RADE/pull/55). This audit did not edit them, and it did not edit docs/NEXT_PROMPT.md at all (pull request 55 changes that file too). Findings there are recommendations.

## Before and after

Commands: `python3 scripts/bloat_check.py --time` (before and after); `git ls-files | wc -l` and `git ls-files -z | xargs -0 du -cb` (files and size).

| Measure | Before | After (this branch) | After all proposals (estimate) | Budget |
|---|---|---|---|---|
| Start read (~tokens) | 12,783 | 12,783 | ~11,000 (A); ~9,100 (A+B) | 6,000 |
| Handoff lines | 37 | 37 | 37 | 40 |
| Duplicate lines (80+ chars, 2+ files) | 9 | 9 | 9 (tests and schemas: pull request 55 first) | 20 |
| Tracked files / size | 80 / 825,526 B | 82 / 840,309 B (this report and the config) | same | — |
| Big files (over 500 KB) | 0 | 0 | 0 | 0 |
| Timing: check (scripts/check.sh) | 158.0 s (new baseline) | 153.5 s (exit 0) | ~80–100 s with P8 | +25 % |
| Timing: session check-in | 1.0 s (new baseline) | 0.7 s | 1.0 s | +25 % |
| Hooks per session / per turn | 0.05 s / 0.04 s | same | same | — |
| Removals proposed / approved / made | 0 | 12 / 0 / 0 | — | — |
| Rules removed or merged | 0 | 0 | 6 if P1–P6 are approved | — |
| Key assumptions: high / medium / low / untraced | — | 3 / 5 / 4 / 0 | — | — |

The start read stays over budget on this branch: every change that makes it smaller removes, moves or rewords a decision or a rule, so it is a proposal (audit rule "Removals need the Administrator's approval").

## Made in this branch (no approval needed)

| Change | Why | Exception |
|---|---|---|
| `.bloat-audit.json` (new) | Step 1.2 and 5.2: timed operations `check` and `checkin` with baselines; `last_audit`. A third timing, `bash tests/engine_test.sh` (151.5 s), was measured once and left out: `check` already runs it, so it doubled every `--time` run (layered timing, category 5). | (a) file made on this branch |
| This report | Step 5.1 | (a) |

No `ignore` globs were added (each one hides files from the scan, so it is a proposal: P11).

## Findings by category

Format: what, where, evidence, cost, proposed fix, risk.

1. Duplication. (a) 7 of 9 duplicate lines: tests/window_driver.ps1 and tests/window_real_driver.ps1 share test-setup lines (bloat_check list). Cost: a fix in one driver can miss the other. Fix: one shared setup file dot-sourced by both (P10, after pull request 55). Risk: low. (b) 1 line: `"at"` timestamp pattern in schemas/rade-checks.schema.json and schemas/rade-installed.schema.json. Fix: a shared `$defs` file, or accept (2 standalone schemas). REC: accept. (c) 1 line: the denylist save in the self-tests of scripts/first_use_check.py:95 and scripts/pii_guard.py:530. These are standalone kit scripts; a shared helper couples them. REC: accept (tech debt T1). (d) AGENTS.md:59 and AGENTS.md:78 both say "Never push with `--no-verify`" (P5).
2. Drift. (a) docs/NEXT_PROMPT.md gives 4 different test counts for tests/engine_test.sh: 36 (item 0), 60 (item 8), 74 (item 9), 89 (item 10); the run today prints `ENGINE pass=93 fail=0`. Fix: one count, in one place (P9). (b) The kit baseline (rhope-ops/archimedes_lever) was not compared: that repo is outside this session's access, and the Administrator's "no kit sync" rule makes a port a hand step anyway.
3. Dead code and files. None found. Each tracked file outside docs/reviews was checked for a reference by name (`git grep -F <basename>`); the 6 files with no reference are loaded by the host or a tool (.claude/agents/*.md by the Agent tool, assets/logo/logo-K-16.png and -512.png are output of scripts/render_logo.js and master copies for other repos (DECISIONS 2026-11-14 "Official logo"), tests/fake-pnp/…/PnP.PowerShell.psd1 by `PSModulePath`). No `_old`, `_v2`, `.bak` or debug files.
4. Stale docs. (a) docs/NEXT_PROMPT.md "Needs the Administrator" says to turn on GitHub Pages and that the bookmark gives a 404 until then; a `curl` of the RADE page address (README.md) returns HTTP 200, and of its apps.json 200, 2026-11-15. Fix: remove the item (P9). (b) AGENTS.md:41 Delivery exception applies "while `scripts/check.local.sh` does not exist"; it exists and check.sh reports `PASS project checks (check.local.sh)` (P1). (c) docs/DECISIONS.md "Engine work" row (2026-11-14) says size in summary, version + sha256 in the window and the JSON results block "ship in the next 90-161.Z round build after R17"; the handoff item 1 still lists them as next, after R24. The timing in the row is stale (open decision 4 in the pull request). (d) docs/DECISIONS.md "UI pass 3" row keeps "Proposal A, B or C: not decided (agent REC: B)"; the "Window redesign: concept 1 approved" row replaces UI pass 3 (A, B, C). (e) No broken relative links in any tracked .md or .html file (script check of every `](path)`).
5. Layered wrappers. Common operation `scripts/check.sh` → `scripts/check.local.sh` → `tests/engine_test.sh` → 51 `pwsh` runs. engine_test is 151.5 of 158.0 s (96 %). No step runs twice inside check.sh.
6. Performance. Profile of tests/engine_test.sh (`PS4='+$EPOCHREALTIME $LINENO '`, `set -x`; 148.1 s total): top 3 costs: fake-PnP runs, line 321, 8 runs, 34.8 s; text-mode rounds, line 36, 15 runs, 33.9 s; window runs, line 105, 5 runs, 26.1 s. Each `pwsh -File` of a built bundle costs about 3–4.5 s (a bare `pwsh -c 1` costs 0.27 s), so the cost is the parse of the ~250 KB bundle, 51 times. Fix: run the independent scenarios in parallel (4 cores) or several scenarios per `pwsh` process (P8, after pull request 55). Estimated saving 40–50 %. Risk: medium (shared temp folders must be split per scenario).
7. Dependencies. Standard library Python and pwsh only; Node only for scripts/render_logo.js and .claude/skills/ui-verify/measure.mjs. Nothing unused found.
8. Repository weight. 825,526 bytes in 80 files; the largest is engine/rade_build.py (248 KB, source). Logo PNGs (56 KB together) are generated by scripts/build_logo.py and committed because the page and the engine embed them. Accept.
9. CI. 3 workflows; pii-guard.yml and window.yml run on `pull_request` and `workflow_dispatch` only, release.yml on `workflow_dispatch` only (AGENTS.md "Checks" rule holds). The repo is public, so Actions minutes are free.
10. Process bloat. None found beyond P9.
11. Tech-debt register: below.
12. Instruction bloat (AGENTS.md, 15,548 B, ~3,900 tokens). Section sizes (`awk` on `## ` headings): Bloat 1,722 B, Personal data 1,427 B, Delivery 1,420 B, Delegation 1,109 B, Project rules 1,090 B, Untrusted input 1,043 B, Git safety 1,040 B. Findings: P1 (stale exception, 474 B), P2 (kit-only "KIT" branch in Start of session, ~308 B; this is a project and gets no kit sync), P3 (Personal data restates the header of scripts/pii_guard.py, which the guard enforces; keep the 5 behavior rules, point to the header for tiers), P4 (Bloat: the cadence numbers repeat `.bloat-audit.json` defaults and `.claude/bloat-audit.md`), P5 (duplicate `--no-verify`), P6 (Project log: the location sentence is overridden by "Project rules"; point to `.claude/project-log.md`).
13. Context cost. docs/DECISIONS.md is 26,001 B (51 % of the start read). 9 rows (3,152 B, ~790 tokens) are wholly or mainly replaced by later rows (P7). 25 window, logo and page rows (10,223 B) restate detail whose canonical place is docs/window-design.md (P7 option B). docs/NEXT_PROMPT.md is 9,573 B in 37 lines: the "Left from review (MINOR)" lists of items 0–10 are about 1,800 B of reference text (P9).
14. Rule accretion. None found that came from one incident without a reason; each rule in AGENTS.md has a dated source or a stated reason.
15. Cross-host duplication. docs/host-prompts.md is a pointer only (446 B). The Administrator's personal preferences repeat 3 repo rules (one question round, check delegated output, no force-push); both are the Administrator's own text. REC: no change.
16. Handoff rot. docs/NEXT_PROMPT.md is in its line budget (37 of 40) but not its purpose: lines of 600–1,400 characters, closed items (Pages) and repeated counts. docs/reviews has 3 files, all under 90 days.
17. Agent-made helpers. None found (category 3).
18. Defensive layering. Not reviewed in engine/rade_build.py (pull request 55 scope). REC: include it in the next audit.
19. Hooks and tools. SessionStart `first_use_check.py` 0.05 s, Stop `stop_check.py` 0.04 s, check-in 1.0 s (3 runs each). No sprawl.
20. Delegation overhead. .claude/orchestration.md (5,535 B) is read on demand only. Not measured further.
21. Output verbosity. The handoff lines (category 16) are the main case.

## Proposals for the Administrator (nothing below is made)

| # | What | Where | Why it exists | Evidence it is stale or duplicate | Saving | Risk | REC |
|---|---|---|---|---|---|---|---|
| P1 | Remove the "while check.local.sh does not exist" exception | AGENTS.md:41 | Kit default, the Administrator 2026-11-13: review as the only gate while no project tests | scripts/check.local.sh exists; check.sh: `PASS project checks` | 474 B | Low: the review rule in Delegation stays | Approve |
| P2 | Drop the KIT branch from Start of session | AGENTS.md:23 | Kit text for the starter kit itself | This repo is a project (first_use_check prints nothing); no kit sync (Project rules) | ~308 B | Low | Approve |
| P3 | Shorten Personal data to the behavior rules + a pointer to the pii_guard.py header | AGENTS.md:74–78 | Kit defaults 2026-11-11, DoD tier 2026-11-15 | Tier detail lives in scripts/pii_guard.py header and is enforced | ~600 B | Medium: an agent reads less before a push; the guard still blocks | Approve |
| P4 | Make the audit cadence a pointer to `.bloat-audit.json` / `.claude/bloat-audit.md` | AGENTS.md:119–120 | Kit default | Same numbers in bloat_check.py DEFAULTS and bloat-audit.md | ~350 B | Low | Approve |
| P5 | Keep one "Never push with `--no-verify`" | AGENTS.md:59, :78 | Both sections came with the kit | Exact repeat | ~30 B | None | Approve |
| P6 | Project log section: point to Project rules + .claude/project-log.md | AGENTS.md "Project log" | Kit default 2026-11-11 | Location line overridden by Project rules | ~400 B | Low | Approve |
| P7 | Move replaced decision rows to docs/decisions-archive.md, unchanged (A); also move window, logo and page rows (B) | docs/DECISIONS.md:38, 39, 47, 65, 66, 68, 71, 72, 79 (A); 25 rows (B) | Decision log grows by design | A: each row is named in a later row's "Replaces"; B: canonical detail in docs/window-design.md | A ~790 tokens; B ~1,900 more | A low; B medium (window decisions leave the start read) | A now; B after pull request 55 merges |
| P8 | Parallel or batched pwsh runs in tests/engine_test.sh | tests/engine_test.sh:36, 105, 321 | Each scenario got its own process for isolation | 51 runs, 3–4.5 s each, 4 cores idle | ~60–75 s per check | Medium | After pull request 55 |
| P9 | Handoff clean-up: one test count, drop the Pages item, move "Left from review" lists to docs/reviews/open-minors.md | docs/NEXT_PROMPT.md items 0–10, "Needs the Administrator" | Each session appends its review leftovers | Counts 36/60/74/89 vs 93 today; Pages 200 | ~450–600 tokens | Low | After pull request 55 (it edits this file) |
| P10 | Shared setup file for the two window drivers | tests/window_driver.ps1, tests/window_real_driver.ps1 | Real driver copied from the stub driver | 7 duplicate lines | 7 dup lines | Low | After pull request 55 |
| P11 | No `ignore` globs now | .bloat-audit.json | — | The 9 duplicates are real | — | — | Accept |
| P12 | Start-read budget: keep 6,000 as the target, or raise it | `.bloat-audit.json` budgets | Kit default | Even A+B leaves ~9,100 | — | Raising it hides growth | Keep 6,000; review after P7 B |

## Assumptions

| # | Assumption | Where used | Source | Confidence |
|---|---|---|---|---|
| 1 | What works on the Administrator's NIPR computer works on every NIPR computer | DECISIONS 2026-11-14 (two Environment rows) | The Administrator's account; not measured | Medium |
| 2 | Paste-and-run needs no ISSM approval | DECISIONS 2026-11-14 | The Administrator's account; the row says "not verified by an agent against an official source" | Low |
| 3 | A 600 KB paste is practical | DECISIONS 2026-11-14 bundle row | Paste time never measured; next 90-161.Z round measures it | Low |
| 4 | Windows PowerShell 5.1 is always there | DECISIONS 2026-11-14 | The Administrator | Medium |
| 5 | PnP.PowerShell 1.12.0 reads the admin flag and writes the install row | NEXT_PROMPT item 8 | Fake module test only | Low |
| 6 | The full computer name marker of the NIPR guardrail means NIPR | DECISIONS 2026-11-15; engine guard | The Administrator, known SIPR gap accepted | Medium |
| 7 | The window lays out right at 150 % and in the ISE host | docs/window-design.md "Proof" | Windows job proves 100 % only | Medium |
| 8 | The work computer reaches the RADE page host and release downloads | DECISIONS 2026-11-14 (bookmark, deploy payload) | NEXT_PROMPT: "NOT verified on a work computer" | Low |
| 9 | The app canary can reach github.com | scripts/check.local.sh | check.sh PASS in this container | High |
| 10 | Actions minutes are no constraint | AGENTS.md "Checks" | Public repo | High |
| 11 | GitHub Pages is on | NEXT_PROMPT "Needs the Administrator" says no | curl 200 today: the handoff is stale | High (it is on) |
| 12 | The engine items of the 2026-11-14 "Engine work" row ship "after R17" | DECISIONS 2026-11-14 | Stale: R24 is past | Medium (needs a new timing) |

Tests for assumptions: 9 and 11 are checked (check.sh, curl). The device assumptions (1, 3, 5, 7, 8) can only be tested in a work-computer round; the next 90-161.Z round already plans 3 and 7.

## Tech-debt register

| # | Item | Administrator | Review date |
|---|---|---|---|
| T1 | Denylist save repeated in two kit self-tests (scripts/first_use_check.py:95, scripts/pii_guard.py:530) | the Administrator | 2026-11-30 (next audit) |
| T2 | Shared `"at"` pattern in two schemas | the Administrator | 2026-11-30 |
| T3 | Engine defensive-layering review not done (pull request 55 scope) | next audit | 2026-11-30 |
| T4 | Kit-baseline drift not compared (no access to rhope-ops/archimedes_lever from this session) | the Administrator | 2026-11-30 |
