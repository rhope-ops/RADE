# Plan: Restore in engine-v31 (2026-11-21)

Status: the Administrator (as PFM) answered the design questions on 2026-11-21 (brief from the 90-161.Z session, 2026-11-20): rows below. Stage 3 of [2026-11-20-plan-maintenance-tools.md](2026-11-20-plan-maintenance-tools.md). Test sites only (2026-11-20). For round R41 of 90-161.Z.

## Decisions (the Administrator, 2026-11-21)

| # | Question | Answer |
|---|---|---|
| 1 | What Restore writes | Missing rows only: a row in the backup that is not on the list. Recycle Bin first (same ID, so lookups stay); else a new row, with lookups to re-made rows re-pointed. A row that is on the list is never changed (engine.md v1 rule kept). |
| 2 | Rows made after the backup | Left as they are; the dry run counts them per list. |
| 3 | Confirm | After the dry run card, the user types the app name; then RADE takes a fresh backup (R3), then writes. |
| 4 | Flows (R2) | Built now, as a pause-switch row: the manifest names a list, a row title, a field and the "on" value. RADE sets it before the write and puts the earlier value back after. The app's flows read it and skip while it is on (app work). |

## Build

1. Manifest `restore` (schema, build): `testSites` (site addresses), optional `pause` {list, title, field, on}. Back up list titles may hold parentheses (R39 open item).
2. Engine part 13: the backup list, the dry run (read-only: counts per list), the write (refuses a site that is not a test site; R3, R2, R1, R5, a count check after; stops before any write when the site changed since the dry run).
3. Window part 11: Restore row on; pick a backup; dry-run card with the typed name; result card.
4. Tests: fake PnP (Recycle Bin, fields, add); tests/tools_unit.ps1 cases; the window stand-in.
5. Docs: engine.md, window-design.md, make-an-app.md, DECISIONS.md; release engine-v31 with the R41 clicks.
