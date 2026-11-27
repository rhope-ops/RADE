# Plan: engine-v48 (UI pass after R47) and 90-161.Z R48

Approved by the PFM, 2026-11-27 07:20 Central: "take every step needed to get this pushed, merged, and so i can do the next round soon" (own message, RADE session), after the decisions below. Previews: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, page "UI pass after R47 (27 Nov)", boards "B + C polished", "Light and dark" and "Cards v2" (the build target). Review: [2026-11-27-ui-critique-bc.md](2026-11-27-ui-critique-bc.md). Source: the PFM's R47 notes and pictures (e-mail, not kept here), R47 results (counts only).

## Decisions (the PFM, question dialogs, 2026-11-27; scope: engine-v48)

| # | Question | Answer |
|---|---|---|
| D1 | Maintenance card when the app is installed | Row 1 "Install <version>" stays, gray and off; row 2 "Repair" (or "Update to <version>"); then Diagnose, Back up, Restore, Uninstall (red). |
| D2 | How RADE decides "installed" | The install record on this computer. Each Uninstall and each round clean-up that removes the app's lists also clears the record (the round clean-up: 90-161.Z). |
| D3 | Release | One release: engine-v48 holds the UI pass and the Remove RADE and Uninstall clean-up (DECISIONS 2026-11-26). |
| D4 | Buttons at half size | Narrow mode stacks, 240 px wide, at the right edge, main button on top (the PFM: "narrow mode stacks ... less wide"); full size: one row, Back at the left end, main at the right end. |
| D5 | Window layout | "B + C": the navy top band of UI pass 3 C with the quiet step rows of B. Replaces the "One thing" layout of 2026-11-14 (cards stay one at a time). |
| D6 | Themes | Light = Kanon in USAF colors; dark = Kanon in Fulcrum colors with the 2.1.0 window roles (kit 15.1.0, PR 231, merged). |
| D7 | Review changes | 1-8 of the critique "Proposed changes"; 10 (failure card, card after "It failed", focus ring, Cancel question) drawn in "Cards v2". |
| D8 | Maintenance, not installed | Single Install button: "Kanon is not installed.", what Install does, blue "Install <version> (Enter)", Back (Esc); the other options only after an install. D1 stays for the installed state. |

## engine-v48 (this repo), in order

| Step | Work | Who | Mark |
|---|---|---|---|
| 1 | Themes: dark token set in engine/ui-tokens.json (Fulcrum 2.1.0 values) beside the light set (USAF; Band #081B33, yellow #FFCD00, off ink #5F6874); the window follows the Windows app mode (light or dark); the logo of the theme (USAF or Fulcrum file of the app) | worker 1 (strong) | in |
| 2 | Band: logo, word, "in RADE", the stage now (white disc, white underline; tick when done); half size drops the subtitle; the light line under it: 4 px off/green, 8 px yellow (your turn) and dark red (failure) | worker 1 | in |
| 3 | Cards: kicker chip YOUR TURN; Run with one percent and one bar (no second percent in the bottom line); running row with summary line, bar, detail line; Done with the green line and the summary line, no Back; not-installed card (D8); Maintenance installed (D1); new cards: after "It failed" (answers), Cancel question, step failed (What to do box) | worker 1 | in |
| 4 | Buttons: full size one row; under about 700 px a 240 px stack at the right edge under the text, main on top 16 px apart; the main button shows its key ("(Enter)"); Esc only where safe (Run: Cancel; Choose: Back), not on Your turn or Done; one height (40) | worker 1 | in |
| 5 | Text wraps to 2 lines, never cut with "..."; the step bar starts on the card edge (R47 indent); the line in capitals clear of the logo block (R47 step 23); "Kanon" name on Done and Run | worker 1 | in |
| 6 | Uninstall clean-up (DECISIONS 2026-11-26): the card asks keep or remove Backups; app folder, runner copy, shortcut, record to the Recycle Bin; the last app's Uninstall clears RADE's shared folder; no "Remove RADE" button | worker 2 (strong) | in |
| 7 | Docs: window-design.md, ui-standard.md (B1, B6, R35 narrow mode), engine.md, README; DECISIONS rows D1-D8 | orchestrator | in |
| 8 | Proof: scripts/check.sh, lint, the Windows job (window.yml) at its scales and contrast theme, plus 956 x 1081 at 150 % (the PFM's half size) | orchestrator | in |
| 9 | Fresh review of each worker branch; merge; release engine-v48 (release.yml); report tag and commit | orchestrator | in |
| - | Kit tag v15.1.0 and the kit sync to RADE and 90-161.Z | Release Manager, later | later |
| - | Full-size drawings of the 7 cards | - | out (same rules as half size) |

## 90-161.Z R48 (the app repo), after the release

1. Lock engine-v48 (docs/dev-setup.md "Commands (full text)").
2. The list step sends one NOW line per list: "Making list N of 12: <list name>" (item 5 of the PFM's notes).
3. The round clean-up that removes the lists also clears the install record (D2).
4. Record the R47 results (the round skill); open items from R47: T22 NEEDS REVIEW (1 failed), T26 Restore dry run numbers.
5. Build and release the R48 bundle; go.md; the next-step link.

## Proof and limits

Cloud proves the layout self-check and the Windows job pictures. Only the work-computer round proves Windows PowerShell 5.1 on the PFM's computer, the dark mode switch and the half-size window.

## Result (2026-11-27)

Released engine-v48 at 9b9b158 (PRs 211 and 212); the Windows job passed 16 of 16 runs; 6 fresh reviews, every MAJOR fixed. Open after the release:
- The answers card after "It failed" (no manifest field holds the answers); "about N min left" on the Run card.
- Text mode has no Uninstall (window only, as before).
- The engine test "r31 L6: the tour and Help" fails at random (also before engine-v48): find the cause.
- After the last app's Uninstall, the same window saves no place or tour mark until it opens again.
- The Release Manager tags kit v15.1.0; then the kit sync to RADE and 90-161.Z.
- R49: the Kanon window in the same style and dark mode, colors from engine/ui-tokens.json (90-161.Z DECISIONS 2026-11-27).
