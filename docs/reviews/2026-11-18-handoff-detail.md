# Handoff detail: RADE, 2026-11-18

Moved out of [docs/NEXT_PROMPT.md](../NEXT_PROMPT.md) on 2026-11-18 (kit port "one check"): the handoff counts toward the session load cap of 6,000 tokens (AGENTS.md "Bloat, drift and assumptions"), so it keeps one short line per item and this file holds the full text. Update the item here when its state changes; keep the same numbers in both files. Older detail: [2026-11-16-handoff-detail.md](2026-11-16-handoff-detail.md).

Header of the handoff before the move: logo 64 px baseline and app row, PRs 98 and 99, ENGINE_RELEASE 15, engine-v15 = 3d9ee5a released 18 Nov 26, palette stays USAF; page header = the 90-161.Z band and tagline "Test, deploy, enjoy" on the page and in the window title, PR 101, ENGINE_RELEASE 16, engine-v16 = b15c624 released 18 Nov 26; 90-161.Z pull request 147 (its header shows the name only) waits for that app's lock move to engine-v16, which the PFM starts; standards plan done, close-out in docs/reviews; engine-v14 = 783dee4 released 17 Nov 26; test speed S1-S4 merged, PR 86; check baseline 66.4 s, PR 89.

## State

- Engine: engine/rade_build.py builds; the engine PowerShell is in engine/ps (21 parts, docs/engine.md "How an app gets the engine"); bundles carry a Contents list, banners and shared blocks (docs/engine.md "Bundle layout"); apps fetch it by commit and own their lock. Latest release engine-v16 = b15c624, 18 Nov 26 (title-bar tagline; the next release raises ENGINE_RELEASE to 17 first). engine-v14 = 783dee4, 17 Nov 26 (no Windows sign-in to any address the engine asks; host rule with port; build stops on a missing part; ENGINE_RELEASE 14, the next release raises it to 15 first). Earlier: engine-v9 (28877e7), engine-v8 (f720098): R28 work of pull requests 72 and 73 (scaling at 125/150 %, Kick fix, window size and place, Start and desktop icon, update notice on the RADE page, selectable text, shared UI file engine/rade_ui.ps1, cancel/boot-error/no-app cards). Runner polish (pull request 71, 6cfc29c; the Administrator, 17 Nov 26): 4 text styles in 1 typeface, manifest step `title`, hand card order with numbered columns and a closing line, hand cards may scroll, guide line 100 / 10 lines (WARNINGs); released as engine-v9. R28 fixes (the Administrator's brief, 17 Nov; DECISIONS): address row only with an address, hand-step lines in one selectable text, file path on the card, shortcut folder on the install card, no fixed heights + self-check for cut lines and dead space, step timer, full text answers, Start on Done and Maintenance, Rho Bold; release engine-v10. Tests: `ENGINE pass=114 fail=0`. Next release: raise ENGINE_RELEASE first (docs/engine.md "Releases"). Nothing after R20 is verified on a device.
- Code standard (the Administrator, 17 Nov 26): docs/code-standard.md = kit core + RADE extras; scripts/code_standard.py (kit port) with its settings in `.check` (`code-c2: full`, `code-c1-safety: on`, `code-max-line-chars: 200`) and its debt in `.check.state.json` (after the kit port of 18 Nov 26: comment 72, length 2, file size 0, full docs 186, safety lines 54, line length 39; stricter checker, row of 17 Nov 26). Fix debt in files you touch; kit-file debt goes to the kit first. Mapping docs/standards-mapping.md; review guide docs/review-guide.md. Stale comment at the next engine change: engine/rade_build.py line 97 names tests/check_code_standard.py.
- Kit: ported to archimedes_lever 2026.11.18 = fbab6b1 ("one check": `.check`, `.check.lock`, `.check.state.json`, scripts/check_content*.py; DECISIONS 2026-11-18); RADE's own versions of kit files are the overrides in `.check.lock` (`python3 scripts/check_lock.py --verify` lists them); next port starts there (`port` skill). The time baselines in `.check.state.json` still hold the step names of the old lane; record new ones by the `efficiency` skill.
- RADE page: https://rhope-ops.github.io/RADE/ (index.html + apps.json on main); NOT verified on a work computer.

## Open (in order)

0. Deploy v1: built, tested in text mode. Next: 90-161.Z lock bump and manifest fields, item 6 (app page), first tagged release.
1. The standards plan (the Administrator, 17 Nov 26; docs/DECISIONS.md): all stages merged (pull requests 87, 88, 94, 95; engine-v14 released; job text51 runs text mode on Windows PowerShell 5.1). What is merged, the proof, the Administrator's settings to do and every open point: [docs/reviews/2026-11-18-standards-plan-close.md](2026-11-18-standards-plan-close.md). Next engine release (15): the catch reasons and the strict-mode faults listed there. The kit must take the four checker files at its next port.
2. Next engine items: size in the summary, engine version + sha256 in the window, JSON results block.
3. Run-time logo: spec docs/specs/run-time-logo.md approved 17 Nov 26 (A2 tolerance set; reference images in tests/ only if needed). Next: build in one engine release, then the 90-161.Z round that drops its PNGs. When built, R7 also removes `application.logo`, `$appLogoPng` and `app_logo_bytes` (DECISIONS 2026-11-18). 90-161.Z: after its lock moves to engine-v15, it adds `application.logo` (docs/make-an-app.md).
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
16. R28 fixes leftovers (pull request 78): N8 = the folder of the RADE shortcut (the Administrator confirmed, 17 Nov); no tests yet for: a path shown as <a path> in the layout line, a saved shortcut folder used on a later deploy, the Start-on-Maintenance note, GuideInkAt; right alignment of 1-9 beside 10 (figure spaces) is not measured; device proof in 90-161.Z R29; full lane: test speed S1-S4 merged (PR 86, 105.5 s -> 66.4 s), new baseline 66.4 s (PR 89; docs/reviews/2026-11-17-test-speed-audit.md); the pull-request check is now named `checks` (the job of check.yml; it was `scan`, the job of pii-guard.yml): a required check named `scan` in the branch settings must be changed to `checks`; the 90-161.Z lock moves to engine-v10 only when the PFM asks.

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine and in apps.json `help`).

## Do not

- None yet.
