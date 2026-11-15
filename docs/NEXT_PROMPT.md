# Next prompt: RADE

Updated: 2026-11-14 by Claude (deploy v1). Keep this file at 40 lines or fewer. The current request overrides it.

## State

- main: bootstrapped from rhope-ops/archimedes_lever. Manifest contract: schemas/rade-manifest.schema.json; `python3 scripts/check_manifest.py <manifest>` checks one (the 90-161.Z manifest passes, 14 Nov 26).
- Engine source: engine/rade_build.py here (AGENTS.md Project rules); 90-161.Z pins eb561ce (layout P1 window; its scripts/rade.lock.json is the source). First gov-device proof: 90-161.Z R20 "Window: OK" and a PASSED repository check. Known cosmetic notes left: Run box not tinted on the current row, old result text under a reset chip, one culture-sensitive StartsWith, Choose list too tall at high DPI (fixed by P1).

## Open (in order)

0. Deploy v1 (docs/engine.md "Deploy v1"; the Administrator, 14 Nov 26): items 1-2 and the step contract (inputs as environment variables, `MADE <kind>: <name>` lines, per-step record) built and tested in text mode (tests/engine_test.sh, 19 checks); the window part (hidden address box and "displayed correctly" box, DONE text) is not verified on a device. Next, in order: steps that PASSED start unticked and automatic steps run first (item 3); the undo screen (item 4); `fetch` from a tagged release (item 5); per-step help text and PASSED (fallback); an app-and-version shape in place of the round for a deploy; the app page (item 6). 90-161.Z step scripts must read `RADE_SITE` (R21 note W4). Left from review: no STOPPED record when a run fails before its first step.
1. Engine moved here (engine/rade_build.py, 14 Nov). Next engine items: size in the summary, engine version + sha256 in the window, JSON results block (DECISIONS 14 Nov).
2. Build docs/engine.md (modes, two check stages, fallback result, fresh fast checks) and the drift check (docs/drift-check.md).
3. Window UI pass P1: merged (PR 15, 14 Nov; engine sha256 b4968af9...08b5). R21 carried it and came back "Window: NOT OK" (item 4). Open review MINOR notes: unused $filler row, focus after a row link, Select-App 0 at start. Spec: docs/window-design.md "Layout P1".
4. R21 window notes W1-W10 and the pre-check before Choose (not built): docs/reviews/2026-11-15-r21-window-notes.md. One UI pass in a separate session, preview first (the Administrator, 15 Nov 26).
5. Before the first drift run: a one-page report field list for the ISSM (Administrator hands it over).

## Needs the Administrator

- The Teams channel name for the help text (DECISIONS 14 Nov: name only, no link).

## Do not

- None yet.
