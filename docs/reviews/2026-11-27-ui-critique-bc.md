# UI critique of the B + C preview, and the Kanon light and dark themes (2026-11-27)

Target: canvas https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, page "UI pass after R47 (27 Nov)", boards "B + C polished" and "Light and dark". Method: the impeccable pack's critique, with 2 separate reviewers (A: design review against the pack's rubric; B: browser measurements). The pack's detector did not run: its launcher file cannot be run (permission denied, exit 126), so B has no detector findings ("unavailable", not "clean").

## Scores (A)

Nielsen heuristics: 23 of 36 (64 %, acceptable); heuristic 9 (errors) not scored, because no failure card is drawn. Cognitive load: 3 of 8 checklist items fail (too many choices on Maintenance, the main action moves, too many progress numbers on Run).

## Measurements (B)

56 of 56 targets are 24 px or larger. No text overflows. 3 color pairs are under 4.5 : 1, all on options that are not available (2.84, 3.39, 3.93 : 1; WCAG exempts them). 18 texts are under 12 px (the stage numbers and the status words).

## Proposed changes (not approved)

1. Yellow means only "your turn": the stage now is white, not yellow. On Your turn the line is 8 px, and the kicker "YOUR TURN" is on a yellow chip.
2. Run card: one percent and one bar for the whole run; remove the second percent from the bottom line and the stage count "3 of 3" at half size.
3. Your turn: keep Done apart from Skip and It failed (24 px gap), in the same order at both sizes; Enter = Done, with the default-button mark drawn.
4. Esc: Back on Your turn and Done takes no Esc key; Done has no Back, or says where it goes.
5. Say "RADE" in the band ("RADE · Kanon 0.1.0") so the person knows which window "RADE stays open" means.
6. Half size: the button stack goes under the text of the card, not at the bottom of the window.
7. Text that is too long wraps to 2 lines; it is never cut with "...".
8. Done: the light line turns green, and the card shows a one-line summary (steps, checks, time).
9. Maintenance, not installed (conflicts with decision D1 of the Administrator, which keeps the list): keep the list, but say "Kanon is not installed." once above it, not on each row, and draw the Uninstall row gray.
10. Draw next: the failure card, the screen after "It failed", the focus ring, and the Cancel question.

## Dark mode (Kanon in Fulcrum): colors to add

Fulcrum's five colors and their derived set do not cover the window. Measured: ember as a bar on a dark track is 2.87 : 1 (needs 3 : 1); the ember link and the soft red error are 1.10 : 1 apart (the same color to the eye). Added on the board, each checked: Band #0E1015, Info #8DB8F0 (links, progress, RUNNING), Run tint #1B2433, Raised #1E2129, Off fill #262A33, Off ink #9599A3, Off red #C98F89, Track #3A3F4A; control line changes from #6E7382 to #7A7F8C. Rule: ember = the main action and the stage now; info blue = links, progress and RUNNING; soft red = errors only.

Light mode (Kanon in USAF): add a Band token #081B33; the yellow changes from #FFD520 to the logo yellow #FFCD00; Off ink changes to #5F6874 on #F4F6F8.

## Cards, version 2 (2026-11-27)

Board "Cards v2" on the same page: 7 half-size cards in both modes (not installed, Run, Your turn, after "It failed", Cancel question, step failed, Done), with changes 1 to 8 and the single Install card (D8). Dark focus ring changes from #FF8C66 to cream #F3EEE4: the orange ring could not be seen around the ember main button.
