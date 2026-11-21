# engine-v31: Maintenance > Restore (release notes, 2026-11-21)

For round R41 of 90-161.Z (test site only). Decisions: [plan](2026-11-21-plan-restore-v31.md); how it works: [../engine.md](../engine.md) "Maintenance run types".

## What is new

- Maintenance > Restore: pick a backup, a dry run with counts per list (nothing written), type the app name, then a fresh backup, the pause switch on, the Recycle Bin (same IDs), new rows for the rest (lookups to re-made rows re-pointed), the pause switch back, and a count check. Missing rows only: a row on the list is never changed; a row made after the backup stays.
- Restore runs only on a site in the manifest's `restore.testSites`; on any other site the card says so and nothing changes.
- Back up: a list title may hold parentheses (the R39 open item: "... (DAF Form 847)" style titles).
- Engine files: 37 (new `engine/rade_fields.py` and `engine/ps/14-restore.ps1`).

## Before R41: app work in 90-161.Z (a session of that app; RADE does not edit it)

1. Manifest: add the 12th list to `backup`; add `restore`: `testSites` (the test site's name) and `pause` (the settings list, the row title, the field and the "on" value).
2. Each flow that writes rows reads the pause-switch row and skips while it is on.
3. Move the lock to engine-v31 (scripts/bump_lock.py) only on the PFM's request.

## R41: what the round clicks (test site)

| # | Do | Pass when |
|---|---|---|
| 1 | Maintenance > Back up | "All 12 lists were saved"; the parentheses list has its .json and .csv |
| 2 | On the site, by hand: delete 3 rows of one list (they go to the Recycle Bin); delete 1 row of a second list and empty it from the Recycle Bin too; add 1 new row to the first list | — |
| 3 | Maintenance > Restore > the newest backup | The dry run says 4 rows would come back: first list 3 from the Recycle Bin and "1 made after the backup stay"; second list 1 as a new row; every other list 0. Nothing on the site changed |
| 4 | Type a wrong name (or the name in other capitals), then Restore | One gray line asks for the app name; nothing runs |
| 5 | Type the app name, then Restore | "Restore put back 4 of 4 rows"; a PASS line for each list; a new folder in Backups (the fresh backup); "The app's pause switch is back as it was" |
| 6 | Check the site | The 3 rows are back with their old IDs; the re-made row has a new ID (a row on the list that looked up the old ID is not changed, so its lookup stays empty: record it); the new row is still there; the pause-switch row has its old value |
| 7 | Maintenance > Restore > the same backup again, then the fresh backup | "Nothing to restore" (no row is made twice) |
| 8 | Results e-mail | Masked counts only, sent by hand |

Not proven before R41 (cloud tests use a fake SharePoint): PnP on Windows PowerShell 5.1 for `Get-PnPRecycleBinItem` (it may need site-collection admin; then the dry run says the Recycle Bin could not be read and every row would come back new: stop and report), person fields written by site user ID, managed-metadata fields by term ID, the lookup re-point on the tenant, and whether rows that looked up a row in the Recycle Bin show it again once it is back.

Known limits: do not close RADE while Restore runs (the pause switch would stay on; the next Restore stops with "on already"; set it back by hand). The Recycle Bin read stops at 5,000 items.
If the dry run says rows are "left out: an earlier Restore wrote them but did not confirm it", check that list by hand. One person runs Restore for the test site, from one RADE folder (the Administrator, 2026-11-21): the record of re-made rows is in that app folder only.
A row left out for a hand check stays left out in later dry runs (its mark is kept on purpose).
