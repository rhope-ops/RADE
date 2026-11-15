# Window redesign: three concepts (15 Nov 26)

Status: **not chosen**. Agent proposals for the Administrator's request of 15 Nov 26 (a redesign from zero, not a refinement of layout P1 or of UI pass 3 A, B, C). The contract is [window-design.md "For a GUI redesign"](../window-design.md#for-a-gui-redesign-what-the-window-must-do). The engine is not changed.

Mockups: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, page "Redesign: 3 concepts (15 Nov)", 25 artboards at 1020 x 760. Each row has two notes: thesis and cost, and where each contract function lives.

## The three

| | 1 One thing (agent REC) | 2 Ledger | 3 Dark cockpit |
|---|---|---|---|
| The window is | One sentence | The install record | An instrument |
| Thesis | It shows one statement or one question. All other data is one key away, in the Record (F2). | RADE writes the record line by line. The open entry holds the one question. Copy gives exactly what you see. | Each check and step has a fixed lamp that stays dark while it is fine. A lit lamp is the only thing that asks for you. |
| It gives up | The overview: no list of checks, steps or files on screen with a question | Emptiness: the page fills during the run, and you must read it to know the state | Sentences: each check and step needs a label of about 20 characters, and a new user must learn the panel |
| Skeleton | White, one left-aligned block, no lists | White page, numbered entries, one open | Navy, fixed panel: display, lamps, message |
| Moves on by | The answer itself (no Next, no Back row) | The button in the open entry; "Change" opens an earlier entry | The keys in the message panel |
| Yellow (your turn) and dark red (FAILED) | A 6 px light on the top edge, in the one or the other color | One tag on the entry | The lit lamp and its tag; the red lamp has a white edge, because dark red on navy is 1.5:1 |
| Blocked app on Choose | A FAILED line with the fix; not a button | A disabled row with a FAILED tag and the fix | A dim tile with FAILED and the fix; the VISIO lamp has a yellow edge |
| Newer version | Third line of the application button | Line under the application row | Box in the left display |
| Made list | The Record, section "Made by this install"; Done gives the counts | Entry 05, open on Done | The left display on Done and after a stop |
| Maintenance (preview) | Its own question: findings, then the five buttons | Entry 03 with a line for each finding | DIAGNOSE lamps, ACTIONS and REMOVE keys, facts in the display |
| Hand step | The window is the guide (it can be made narrow beside the browser) | Inside entry 04 | Lines in the left display, keys in the message panel |
| Dark parts RADE must draw | None | None | Lamps, ring, keys, input border, the exit question. The title bar and the folder picker stay light |
| Window code (today 80 KB of 600 KB) | 45 to 55 KB | 60 to 70 KB | 85 to 100 KB |
| Engine work | Small: the order of "what needs the person next" | Medium: one record text for the window, the report and the clipboard | Large: a short label for each check and step in the manifest schema |
| Decisions it changes | Rail, three named screens, Next / Back / Exit row, two-line check rows, chips, log on screen | The same, but the log tail stays | The same, plus the white ground and the blue primary button |

Confidence in the size and work estimates: low (no code written). All three build the base checks before Choose and R21 notes W3, W6, W8, W9 and W10; W1, W2, W5 and W7 name parts that no longer exist.

Same in all three (agent choices, not decided): no Exit button (Esc or the window X; the question shows only while a step runs); the step bar is not green, so green means "passed" only; the owner's test extras are one dashed box on Done.

Decided by the Administrator, 15 Nov 26 ([DECISIONS.md](../DECISIONS.md)): FAILED and NEEDS REVIEW are dark red #8B1A1A, so yellow means "your turn" only; the redesign has no Exit button. No concept is chosen.

Maintenance: one artboard for each concept shows the screen of [engine.md "Maintenance run types"](../engine.md#maintenance-run-types) (an agent recommendation, not approved) after Diagnose, with no backup yet: Back up is the primary button, Restore and Uninstall are off, Uninstall is set apart. Not drawn: the Restore choice with its dry run, and the Uninstall confirmation. "Back" and "Copy summary" stay; "Exit" follows the decision above.

## Measured

Method: [measure script of the ui-verify skill](../../.claude/skills/ui-verify/SKILL.md) (its `audit()` for contrast and targets) on each artboard in Chromium at 1020 x 760 (100 %) and 1020 x 616 (150 % on 1920 x 1080), 50 runs, 15 Nov 26. The skill's own widths (375 and 1440 px, dark scheme) do not apply to a fixed-size window mockup. Font: Inter, because Segoe UI is not on the build computer; Inter is wider, so widths are on the safe side. Not measured on a device.

| | 1 One thing | 2 Ledger | 3 Dark cockpit |
|---|---|---|---|
| Artboards x sizes | 9 x 2 | 8 x 2 | 8 x 2 |
| Text below 4.5:1 | 0 | 0 | 0 |
| Targets below 24 x 24 px (smallest) | 0 (24) | 0 (24) | 0 (24) |
| Clipped text, parts outside the window | 0, 0 | 0, 0 | 0, 0 |
| Controls with no accessible name | 0 | 0 | 0 |
| Tab stops in a state | 0 to 6 | 0 to 6 | 0 to 7 |

By hand: the focus ring is 2 px navy on white (15.6:1) or white on navy (15.6:1). Not checked in a mockup: tab order and reduced motion (the mockups do not move).

## Risks

- 1: the yellow light is 1.4:1 on white, so it is weak as a signal by itself; the words "YOUR TURN" carry the meaning (the dark red light is 9.3:1). A navy line under it is a fix if it is too weak on a device.
- 1: a user who wants to see what RADE does must find F2. The Record is the densest view (3 columns).
- 2: the fit at 150 % depends on the rule "one entry open". More than 6 steps or 5 applications need a second rule.
- 3: the lamp outlines are about 2.1:1 (computed; decorative; the mark and the label carry the state). A label and its word together must stay below about 22 characters. At 150 % the Choose panel holds 4 applications.
- 3: it shares the navy ground with the earlier C. The layout is different, but it is the nearest of the three to prior art.

## Recommendation (agent, not a decision)

**REC: 1 One thing.** Reasons: it is the direct form of "quiet when fine, one question at a time"; when a run fails, the cause, the fix and the channel name are the only text on screen; it has the smallest code (about 30 KB less than today) and no manifest change. Confidence: medium. The main cost is the hidden overview; if the Administrator wants the run visible at all times, 2 Ledger is the better choice. 3 has the strongest "issued equipment" look and the highest cost and risk.
