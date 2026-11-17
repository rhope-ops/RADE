# Next prompt: RADE

Updated: 2026-11-17 by Claude (R28 engine work, releases engine-v7 and engine-v8). Keep this file at 40 lines or fewer, one line per item. The current request overrides it. Detail of items 0-11 and the MINOR review leftovers: [docs/reviews/2026-11-16-handoff-detail.md](reviews/2026-11-16-handoff-detail.md).

## State

- Engine: engine/rade_build.py; apps fetch it by commit and own their lock (docs/engine.md). Last release engine-v8 (f720098; engine-v7 619c78b): R28 work of pull requests 72 and 73 (scaling at 125/150 %, Kick fix, window size and place, Start and desktop icon, update notice on the RADE page, selectable text, shared UI file engine/rade_ui.ps1, cancel/boot-error/no-app cards). Tests: `ENGINE pass=101 fail=0`. Next release: raise ENGINE_RELEASE first (docs/engine.md "Releases"). Nothing after R20 is verified on a device.
- Kit: ported to archimedes_lever c523a21 (kit pull requests 19-25); next port starts there (`port` skill).
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
12. R28 leftovers (reviews of PR 72): no test for the kept runner copy; release.yml does not check ENGINE_RELEASE against the tag (guard file: the Administrator decides); Start waits 2.5 s; the shortcut's minimized console hides text-mode fallback; the no-app card cannot be reached in a real build. Device proof pending: 125/150 % text, .lnk, runner copy, ISE text capture (round R28 of 90-161.Z).

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine and in apps.json `help`).

## Do not

- None yet.
