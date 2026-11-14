# Next prompt: RADE

Updated: 2026-11-14 by Claude. Keep this file at 40 lines or fewer. The current request overrides it.

## State

- main: bootstrapped from rhope-ops/archimedes_lever. Manifest contract: schemas/rade-manifest.schema.json; `python3 scripts/check_manifest.py <manifest>` checks one (the 90-161.Z manifest passes, 14 Nov 26).
- Engine source: engine/rade_build.py here (AGENTS.md Project rules); 90-161.Z pins 0e2bbf6 (layout A window, TLS 1.2 before checks, check text; PRs 12-13, 14 Nov 26). First gov-device proof: 90-161.Z R20 "Window: OK" and a PASSED repository check. Known cosmetic notes left: Run box not tinted on the current row, old result text under a reset chip, one culture-sensitive StartsWith, Choose list too tall at high DPI (fixed by P1).

## Open (in order)

1. Engine moved here (engine/rade_build.py, 14 Nov). Next engine items: size in the summary, engine version + sha256 in the window, JSON results block (DECISIONS 14 Nov).
2. Build docs/engine.md (modes, two check stages, fallback result, fresh fast checks) and the drift check (docs/drift-check.md).
3. Window UI pass P1: merged (PR 15, 14 Nov; engine sha256 b4968af9...08b5). 90-161.Z keeps its lock at 0e2bbf6 until its flow-controls round, which becomes R21 and carries the new window; R20 then leaves its build (the Administrator, 14 Nov). Then check R21's "Window: OK". Open review MINOR notes: unused $filler row, focus after a row link, Select-App 0 at start. Spec: docs/window-design.md "Layout P1".
4. Before the first drift run: a one-page report field list for the ISSM (Administrator hands it over).

## Needs the Administrator

- None.

## Do not

- None yet.
