# Next prompt: RADE

Updated: 2026-11-14 by Claude. Keep this file at 40 lines or fewer. The current request overrides it.

## State

- main: bootstrapped from rhope-ops/archimedes_lever. Manifest contract: schemas/rade-manifest.schema.json; `python3 scripts/check_manifest.py <manifest>` checks one (the 90-161.Z manifest passes, 14 Nov 26).
- Engine source: still rhope-ops/90-161.Z scripts/build_paste_bundles.py (AGENTS.md Project rules). Size test (300 KB) in its tests; queued for the round after R17 there: size in the summary, hash-pinned engine, JSON results block (DECISIONS 14 Nov 26).

## Open (in order)

1. Engine moved here (engine/rade_build.py, 14 Nov). Next engine items: size in the summary, engine version + sha256 in the window, JSON results block (DECISIONS 14 Nov).
2. Build docs/engine.md (modes, two check stages, fallback result, fresh fast checks) and the drift check (docs/drift-check.md).
3. Build the window as layout B with logo K: every UI rule and its build state is in docs/window-design.md.
4. Before the first drift run: a one-page report field list for the ISSM (Administrator hands it over).

## Needs the Administrator

- None.

## Do not

- None yet.
