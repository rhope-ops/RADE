# Next prompt: RADE

Updated: 2026-11-16 by Claude (kit port). Keep this file at 40 lines or fewer, one line per item. The current request overrides it. Detail of items 0-11 and the MINOR review leftovers: [docs/reviews/2026-11-16-handoff-detail.md](reviews/2026-11-16-handoff-detail.md).

## State

- Engine: engine/rade_build.py; apps fetch it by commit and own their lock (docs/engine.md). Last release engine-v4 (4a0fbad). Tests: `ENGINE pass=93 fail=0` (tests/engine_test.sh). Nothing after R20 is verified on a device.
- RADE page: https://rhope-ops.github.io/RADE/ (index.html + apps.json on main); NOT verified on a work computer.

## Open (in order)

0. Deploy v1: built, tested in text mode. Next: 90-161.Z lock bump and manifest fields, item 6 (app page), first tagged release.
1. Next engine items: size in the summary, engine version + sha256 in the window, JSON results block.
2. Build docs/engine.md (modes, check stages, fallback, fresh fast checks) and the drift check (docs/drift-check.md).
3. Window "One thing": built, engine-v4; Windows job passes at 100 %. Next: each app moves its lock to engine-v4, then a work-computer round ("Layout self-check: PASS layout").
4. After the first device round: fix what it reports, release, report the tag and commit.
5. Before the first drift run: a report field list for the ISSM (the Administrator hands it over).
6. RADE and the app: next the maintenance run types (function list not approved).
7. Maintenance: only Install works; Diagnose, Back up, Restore, Uninstall need engine functions.
8. Guardrails: built, text-mode tested; device proof of the area52 check and PnP 1.12.0 pending.
9. Shared files: built; a 90-161.Z round must show 4 `PASS shared files` lines (the 5.1 proof).
10. After R24: questions, taskbar restore, bottom line, SCALE line built, release pending; the question-card PNGs need the Administrator's approval.
11. MINOR review leftovers (PR 33, 44, 54 and others): the list in the detail file, for the next engine change.
12. After this PR merges: set `timings.check.seconds` in `.bloat-audit.json` to the median of 3 full-lane runs on main (`--time --record` stores one run only; DECISIONS 2026-11-16).

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine and in apps.json `help`).

## Do not

- None yet.
