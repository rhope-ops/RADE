# Next prompt: RADE

Updated: 2026-11-14 by Claude (deploy v1). Keep this file at 40 lines or fewer. The current request overrides it.

## State

- main: bootstrapped from rhope-ops/archimedes_lever. Manifest contract: schemas/rade-manifest.schema.json; `python3 scripts/check_manifest.py <manifest>` checks one (the 90-161.Z manifest passes, 14 Nov 26).
- Engine source: engine/rade_build.py here (AGENTS.md Project rules); 90-161.Z pins fe32673 (the "One thing" window, engine sha256 3036c97a...8b60; its scripts/rade.lock.json is the source; its bundle is R22 r2, 14 Nov 26). First gov-device proof: 90-161.Z R20 "Window: OK" and a PASSED repository check. Known cosmetic notes left: Run box not tinted on the current row, old result text under a reset chip, one culture-sensitive StartsWith, Choose list too tall at high DPI (fixed by P1).

## Open (in order)

0. Deploy v1 (docs/engine.md "Deploy v1" and "Step contract"; the Administrator, 14 Nov 26): the engine is function complete: items 1-5, the step contract, per-step help, PASSED (fallback), the newer-version notice and the made list are built and tested in text mode (tests/engine_test.sh, 36 checks). Nothing is verified on a device. Next: (b) 90-161.Z: bump the lock, read `RADE_SITE`, add `after`, `makes` and `help`, move large files to `fetch` (its bundle would be 288 KB with this engine; the limit goes from 300 KB to 600 KB, DECISIONS 14 Nov); (c) item 6, the app page, and a first tagged release; (d) remove the test branch after the owner's test rounds end. Left from review (MINOR, for the next engine change): the newer-version compare reads 1.0 as older than 1.0.0 (use three-part versions until fixed); its 4 s timeout does not cover a slow read; test gaps for an optional step that fails, a chain of three `after` steps, a FALLBACK step that fails and the ScreenOnly rule.
1. Engine moved here (engine/rade_build.py, 14 Nov). Next engine items: size in the summary, engine version + sha256 in the window, JSON results block (DECISIONS 14 Nov).
2. Build docs/engine.md (modes, two check stages, fallback result, fresh fast checks) and the drift check (docs/drift-check.md).
3. Window: the "One thing" redesign is built (14 Nov 26; spec docs/window-design.md; it replaced layout P1 and the UI pass 3 proposals, and it covers R21 notes W1-W10 and the base checks before Choose). Its logic is tested with stand-in types (tests/engine_test.sh "window", 4 scenarios); it is NOT verified on a device: the next 90-161.Z round is the first proof ("Window: OK"). Maintenance is a shell: only Install works.
4. After the first device round with the new window: fix what the round reports, then bump each app lock again (AGENTS.md Project rules). Left from the 6 review rounds of PR 33 (MINOR, for the next engine change): the "WIN paged=" test line proves nothing (the stand-in scroll position is not a number); no test for closing the window in a run, a step that asks for a folder, the sign-in button on a failed sign-in card, or the base-result rules; the stand-in types accept any layout or paint member, so drawing code is first tested on a device; a disabled flat button may ignore its text color.
5. Before the first drift run: a one-page report field list for the ISSM (Administrator hands it over).

6. RADE and the app (docs/engine.md, 14 Nov 26): move the base checks from rhope-ops/90-161.Z scripts/build_paste_bundles.py (`BASE_CHECKS`) into the engine; then the maintenance run types (function list not approved yet).

7. Maintenance (decided 14 Nov 26: 5 buttons, docs/engine.md "Maintenance run types"; the function lists D1-D8 and R1-R7 are still an agent REC): the window shows the screen with only Install on; Diagnose, Back up, Restore and Uninstall need their engine functions. Mockups for Restore and Uninstall: the canvas in docs/window-design.md.

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine, DECISIONS 14 Nov).

## Do not

- None yet.
