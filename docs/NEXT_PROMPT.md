# Next prompt: RADE

Updated: 2026-11-14 by Claude (deploy v1). Keep this file at 40 lines or fewer. The current request overrides it.

## State

- main: bootstrapped from rhope-ops/archimedes_lever. Manifest contract: schemas/rade-manifest.schema.json; `python3 scripts/check_manifest.py <manifest>` checks one (the 90-161.Z manifest passes, 14 Nov 26).
- Engine source: engine/rade_build.py here (AGENTS.md Project rules); 90-161.Z pins eb561ce (layout P1 window; its scripts/rade.lock.json is the source). First gov-device proof: 90-161.Z R20 "Window: OK" and a PASSED repository check. Known cosmetic notes left: Run box not tinted on the current row, old result text under a reset chip, one culture-sensitive StartsWith, Choose list too tall at high DPI (fixed by P1).

## Open (in order)

0. Deploy v1 (docs/engine.md "Deploy v1" and "Step contract"; the Administrator, 14 Nov 26): the engine is function complete: items 1-5, the step contract, per-step help, PASSED (fallback), the newer-version notice and the made list are built and tested in text mode (tests/engine_test.sh, 32 checks). Nothing is verified on a device or in the window. Next: (a) the GUI redesign, in its own session, from docs/window-design.md "For a GUI redesign" (preview first); (b) 90-161.Z: bump the lock, read `RADE_SITE`, add `after`, `makes` and `help`, move large files to `fetch` (its bundle would be 288 KB with this engine; the limit goes from 300 KB to 600 KB, DECISIONS 14 Nov); (c) item 6, the app page, and a first tagged release; (d) remove the test branch after the owner's test rounds end. Left from review (MINOR, for the next engine change): the newer-version compare reads 1.0 as older than 1.0.0 (use three-part versions until fixed); its 4 s timeout does not cover a slow read; test gaps for an optional step that fails, a chain of three `after` steps, a FALLBACK step that fails and the ScreenOnly rule.
1. Engine moved here (engine/rade_build.py, 14 Nov). Next engine items: size in the summary, engine version + sha256 in the window, JSON results block (DECISIONS 14 Nov).
2. Build docs/engine.md (modes, two check stages, fallback result, fresh fast checks) and the drift check (docs/drift-check.md).
3. Window UI pass P1: merged (PR 15, 14 Nov; engine sha256 b4968af9...08b5). R21 carried it and came back "Window: NOT OK" (item 4). Open review MINOR notes: unused $filler row, focus after a row link, Select-App 0 at start. Spec: docs/window-design.md "Layout P1".
4. R21 window notes W1-W10 and the pre-check before Choose (not built): docs/reviews/2026-11-15-r21-window-notes.md. Three proposals (A Refine, B Quiet, C Command) are in that file ("UI pass 3 proposals"); the Administrator has not chosen one (agent REC: B) and gives the build prompt after the current RADE expansion (14 Nov 26, evening). Do not build before that. Redesign from zero (14 Nov 26, evening): three concepts (1 One thing, agent REC; 2 Ledger; 3 Dark cockpit) with a Maintenance preview; concept 1 goes forward as the mockup, build not approved (PR 27 stays open until the Administrator says so; DECISIONS 14 Nov): docs/reviews/2026-11-14-window-redesign-proposals.md.
5. Before the first drift run: a one-page report field list for the ISSM (Administrator hands it over).

6. RADE and the app (docs/engine.md, 14 Nov 26): move the base checks from rhope-ops/90-161.Z scripts/build_paste_bundles.py (`BASE_CHECKS`) into the engine; then the maintenance run types (function list not approved yet).

7. Maintenance screen (decided 14 Nov 26: 5 buttons, docs/engine.md "Maintenance run types"; the function lists D1-D8 and R1-R7 are still an agent REC): the GUI session draws it, preview first.

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine, DECISIONS 14 Nov).

## Do not

- None yet.
