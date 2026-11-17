# Next prompt: RADE

Updated: 2026-11-17 by Claude (code standard and engine split; engine-v11 = 19ba54b released 17 Nov 26; ENGINE_RELEASE = 12 for the lint-clean names, release engine-v12 after the merge). Keep this file at 40 lines or fewer, one line per item. The current request overrides it. Detail of items 0-11 and the MINOR review leftovers: [docs/reviews/2026-11-16-handoff-detail.md](reviews/2026-11-16-handoff-detail.md).

## State

- Engine: engine/rade_build.py builds; the engine PowerShell is in engine/ps (21 parts, docs/engine.md "How an app gets the engine"); bundles carry a Contents list, banners and shared blocks (docs/engine.md "Bundle layout"); apps fetch it by commit and own their lock. Releases engine-v9 (28877e7), engine-v8 (f720098): R28 work of pull requests 72 and 73 (scaling at 125/150 %, Kick fix, window size and place, Start and desktop icon, update notice on the RADE page, selectable text, shared UI file engine/rade_ui.ps1, cancel/boot-error/no-app cards). Runner polish (pull request 71, 6cfc29c; the Administrator, 17 Nov 26): 4 text styles in 1 typeface, manifest step `title`, hand card order with numbered columns and a closing line, hand cards may scroll, guide line 100 / 10 lines (WARNINGs); released as engine-v9. R28 fixes (the Administrator's brief, 17 Nov; DECISIONS): address row only with an address, hand-step lines in one selectable text, file path on the card, shortcut folder on the install card, no fixed heights + self-check for cut lines and dead space, step timer, full text answers, Start on Done and Maintenance, Rho Bold; release engine-v10. Tests: `ENGINE pass=108 fail=0`. Next release: raise ENGINE_RELEASE first (docs/engine.md "Releases"). Nothing after R20 is verified on a device.
- Code standard (the Administrator, 17 Nov 26): docs/code-standard.md = kit core + RADE extras; scripts/code_standard.py (kit port) with .code-standard.json, C2 full and C1 safety on (debt: comment 73, length 2, file size 1, full docs 215, safety lines 59). Fix debt in files you touch; kit-file debt goes to the kit first. Mapping docs/standards-mapping.md; review guide docs/review-guide.md. Stale comment at the next engine change: engine/rade_build.py line 97 names tests/check_code_standard.py.
- Kit: ported to archimedes_lever c523a21 (kit pull requests 19-25); next port starts there (`port` skill).
- RADE page: https://rhope-ops.github.io/RADE/ (index.html + apps.json on main); NOT verified on a work computer.

## Open (in order)

0. Deploy v1: built, tested in text mode. Next: 90-161.Z lock bump and manifest fields, item 6 (app page), first tagged release.
1. Reach test sends no Windows sign-in to the tested address; Config flow address only on the app's host (ENGINE_RELEASE 13, tests/net_rules_test.sh). Next: release engine-v13 after the Administrator's go, then each app moves its lock; a work-computer round proves the reach check.
2. Next engine items: size in the summary, engine version + sha256 in the window, JSON results block.
3. Run-time logo: spec docs/specs/run-time-logo.md approved 17 Nov 26 (A2 tolerance set; open: reference images in tests/ if the Windows runner cannot render them). Next: build in one engine release, then the 90-161.Z round that drops its PNGs.
4. Build docs/engine.md (modes, check stages, fallback, fresh fast checks) and the drift check (docs/drift-check.md).
5. Window "One thing": built, engine-v4; Windows job passes at 100 %. Next: each app moves its lock to engine-v4, then a work-computer round ("Layout self-check: PASS layout").
6. After the first device round: fix what it reports, release, report the tag and commit.
7. Before the first drift run: a report field list for the ISSM (the Administrator hands it over).
8. RADE and the app: next the maintenance run types (function list not approved).
9. Maintenance: only Install works; Diagnose, Back up, Restore, Uninstall need engine functions.
10. Guardrails: built, text-mode tested; device proof of the area52 check and PnP 1.12.0 pending.
11. Shared files: built; a 90-161.Z round must show 4 `PASS shared files` lines (the 5.1 proof).
12. After R24: questions, taskbar restore, bottom line, SCALE line built, release pending; the question-card PNGs need the Administrator's approval.
13. MINOR review leftovers (PR 33, 44, 54 and others): the list in the detail file, for the next engine change.
14. R28 leftovers (reviews of PR 72): no test for the kept runner copy; release.yml does not check ENGINE_RELEASE against the tag (guard file: the Administrator decides); Start waits 2.5 s; the shortcut's minimized console hides text-mode fallback; the no-app card cannot be reached in a real build. Device proof pending: 125/150 % text, .lnk, runner copy, ISE text capture (round R28 of 90-161.Z).

15. Runner polish leftovers (reviews of pull request 71): `$ui.Say` sets the last log line without a new edge fit (stale edge possible, not seen in the job); `$ui.Fit` breaks long words before `FitSteps` sets the numbered widths (the 400 ms refit corrects it); no stand-in test covers `OnStatus`/`ShowRun`; option: only the numbered lines scroll on a hand card (today the whole text above the buttons scrolls).
16. R28 fixes leftovers (pull request 78): N8 = the folder of the RADE shortcut (the Administrator confirmed, 17 Nov); no tests yet for: a path shown as <a path> in the layout line, a saved shortcut folder used on a later deploy, the Start-on-Maintenance note, GuideInkAt; right alignment of 1-9 beside 10 (figure spaces) is not measured; device proof in 90-161.Z R29; full lane 90 s vs baseline 45.7 s (efficiency skill); the 90-161.Z lock moves to engine-v10 only when the PFM asks.

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine and in apps.json `help`).

## Do not

- None yet.
