# Plan: the Maintenance screen and its tools (2026-11-20)

Status: approved by the Administrator, 2026-11-20 (questions 2 to 4 below: yes; all three tools in the next release after engine-v29, not one each; the UI standard became engine-v29 because another change took engine-v28). Asked by the Administrator (as PFM, 2026-11-20, relayed by the 90-161.Z session): keep Diagnose, Back up and Restore, put them with Update/Repair on their own Maintenance screen, and build them far enough to be tested. The run types are decided in [../engine.md](../engine.md) "Maintenance run types" (2026-11-14); the function lists there are an agent recommendation, not yet approved. This plan orders the build and names what a test round checks. It adds D0 (the checks again) and, for this first build, leaves out D5 to D8, R6 and R7; Restore v1 keeps engine.md's rule "missing rows only, no overwrite". The function list for the build comes back to the Administrator with the next PR.

## Stage 0: the screen (built in PR 136, engine-v29)

The Maintenance card: Start, Maintenance, Uninstall (not available). The Maintenance screen (view `tools`): Diagnose, Back up, Restore (not available) and Update/Repair (works) as the primary, Back (Esc). Follows B1 to B13. Proof: the stand-in tests and the Windows job's pictures (the preview).

## Stage 1: Diagnose (read-only; engine-v29)

| Function | What it does | Writes |
|---|---|---|
| D1 | The installed record against the newest version in the paste | none |
| D0 | The RADE checks of the app again (as the Ready card runs them) | none |
| D2-D4 | Schema, permission and settings-row compare against the app's schema file | none; needs the app's schema file (app work) |
| Report | One report file in the app's results folder, each finding with its fix | the report file |

Test round checks: Diagnose on a good install says PASS; with a step file removed by hand it names the file and the fix; nothing on the site changes (the site's list counts before and after).

## Stage 2: Back up (reads the site, writes on the computer; engine-v30)

Each list the app's manifest names (a new manifest field, schema change) is read through PnP and saved as JSON plus a CSV copy in `RADE\<app>\Backups\<date-time>`. Nothing on the site changes. Test round checks: the row count of each file equals the list's count on the site; a second backup makes a new folder; a list the account cannot read is reported, not skipped silently.

## Stage 3: Restore (WRITES SITE ROWS; engine-v31 at the earliest)

R1 Recycle Bin restore first; else rows from a backup the user picks, after R3 (a fresh backup), R4 (a dry run with counts the user confirms by typing the app name), R2 (flows paused before, resumed after), R5 (dependency order, lookup IDs remapped). A live data write: test sites only until the Administrator approves it for a real site. Test round checks: on a test site, delete 3 rows, restore them; the dry-run counts match; the flows are on again; the fresh backup exists.

## Questions for the Administrator

1. Order: Stage 0 now (engine-v28, R38), then Diagnose, then Back up, then Restore, one release each? (REC: yes.)
2. Restore on test sites only until a test round passes and you approve it for a real site? (REC: yes.)
3. Back up's list names come from a new manifest field that each app fills in (RADE never knows an app's lists)? (REC: yes.)
