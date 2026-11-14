# Next prompt: RADE

Updated: 2026-11-14 by Claude. Keep this file at 40 lines or fewer. The current request overrides it.

## State

- main: bootstrapped from rhope-ops/archimedes_lever. Manifest contract: schemas/rade-manifest.schema.json; `python3 scripts/check_manifest.py <manifest>` checks one (the 90-161.Z manifest passes, 14 Nov 26).
- Engine source: still rhope-ops/90-161.Z scripts/build_paste_bundles.py (AGENTS.md Project rules). Size test (300 KB) in its tests; queued for the round after R17 there: size in the summary, hash-pinned engine, JSON results block (DECISIONS 14 Nov 26).

## Open (in order)

1. After R17 confirms the window: move the engine here, with the manifest schema as its input contract.
2. Build the drift check (docs/drift-check.md) with the engine move. Open: when it runs, and the ISSM field list (agent RECs in that file).

## Needs the Administrator

- None.

## Do not

- None yet.
