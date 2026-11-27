# Plan: engine-v48, UI pass after 90-161.Z R47 (draft, not approved)

Started: 2026-11-27 06:15 Central. Status: questions open (button layout). Source: the PFM's R47 notes and pictures (sent by e-mail, not kept in this repo), and the R47 results (counts only).

## Decisions (the PFM, question dialog, 2026-11-27; scope: engine-v48)

| # | Question | Answer |
|---|---|---|
| D1 | Maintenance card when the app is installed | Row 1 "Install <version>" stays, gray and off; row 2 "Repair" (or "Update to <version>"); then Diagnose, Back up, Restore, Uninstall (red). |
| D2 | How RADE decides "installed" | The install record on this computer (no sign-in before the card). Each Uninstall and each round clean-up that removes the app's lists also clears the record. |
| D3 | Release | One release: engine-v48 holds this UI pass and the planned Remove RADE and Uninstall clean-up (DECISIONS 2026-11-26). |
| D4 | Buttons at half size | Open: the PFM asked for a preview of all 3 options. Preview: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, page "UI pass after R47 (27 Nov)". |
| D5 | Window layout | Open (the PFM, 2026-11-27, after the button preview: "I forgot how much I liked option A"): preview two hybrids of UI pass 3: the top band of C with the body of A, and with the body of B, at full and half size (same page). A hybrid replaces the "One thing" design (2026-11-14): a design change that needs the PFM's approval before a build. |

## Items (from the PFM's notes)

1. Maintenance card when the app is not installed: headline "Select an option."; row 1 "Install <version>" in blue (an edge and text in blue, as Uninstall is in red); the other rows off unless an earlier install left data or backups (D1).
2. Maintenance card when installed: "<word> <version> is installed." and the D1 rows.
3. Buttons at half size: one layout from D4.
4. Run card: the bar is indented a few pixels from the card's left edge at half size ("One left edge" rule).
5. Run card: the line above the bar is a summary of the step; the line below is the detail, with counts ("Making list 3 of 12: <list name>"). The count lines come from the app's step script (NOW lines): a 90-161.Z change, made by a 90-161.Z session ("App repos" rule).
6. Header: the line in capitals ("STEP 23 OF 24") is too close to the logo block; add space.
7. Done and Run cards say "90-161.Z" where Maintenance says "Kanon": use the app word (engine-v47 branding).
8. Remove RADE and Uninstall clean-up (DECISIONS 2026-11-26).

Reference size: the PFM's half-size window is 956 x 1081 px at 150 % (about 637 x 720 at 100 %). Add it to the Windows job.

Not in this plan (90-161.Z results of R47, for its own session): T22 "Open the 90-161.Z window" NEEDS REVIEW (1 failed); T26 Restore dry run showed other numbers (4 from recycle, 0 as new rows).
