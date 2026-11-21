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

1. Manifest `restore` (schema, build): `testSites` (site names: the part after the site prefix; changed from "site addresses" in the build so no address is in a manifest), optional `pause` {list, title, field, on}. Back up list titles may hold parentheses (R39 open item).
2. Engine part 13: the backup list, the dry run (read-only: counts per list), the write (refuses a site that is not a test site; R3, R2, R1, R5, a count check after; stops before any write when the site changed since the dry run).
3. Window part 11: Restore row on; pick a backup; dry-run card with the typed name; result card.
4. Tests: fake PnP (Recycle Bin, fields, add); tests/tools_unit.ps1 cases; the window stand-in.
5. Docs: engine.md, window-design.md, make-an-app.md, DECISIONS.md; release engine-v31 with the R41 clicks.

## Review of PR 151 (fresh reviewer, 2026-11-21)

MAJOR fixed: the record of re-made rows was one per backup folder, so two backups could make the same row twice; it is now `Backups\~restore-map.json`, one for the app. MINOR fixed: the write checks a hash of the missing and Recycle Bin rows, not only their count; after a Recycle Bin error the list is read again; the typed name must match exactly. MINOR kept, in the release notes: closing RADE mid-run leaves the pause switch on; the Recycle Bin read stops at 5,000 items.

Second review (fix c812037): MAJOR fixed: the record is one file for each site (`Backups\~restore-map-<site hash>.json`), and a chain of re-made rows is followed to its end. MINOR fixed: a list that cannot be read again after the Recycle Bin stops the new rows and the result says so; old wording; the Windows job's line check.

Third review (fix 6ca3583): MAJOR fixed by a new model: the record holds links (old ID - new ID); all linked IDs are one row, found on the list or in the Recycle Bin by any of its IDs; tests cover the reviewer's order (A, then B) and a later ID in the Recycle Bin. MINOR (a middle ID of a chain on the list) is covered by the same model. NIT: the site hash uses Get-SiteMark.
