# RADE window design

Status: the one place for the RADE window's UI decisions (the Administrator, 2026-11-14: consolidate them). The window is the "One thing" design (the Administrator, 2026-11-14, [DECISIONS.md](DECISIONS.md)); it replaced layout B, layout A, layout P1 and the UI pass 3 proposals. Built in [engine/rade_build.py](../engine/rade_build.py) (WinForms drawn in code, Windows PowerShell 5.1); the window code is the part from `function Get-AppFact` to the text-mode block. **Not verified on a device**: its logic runs in [tests/engine_test.sh](../tests/engine_test.sh) (section "window") against stand-in types; its layout is measured on the real Windows Forms by the Windows job and by the layout self-check ("Proof" below); a round on a work computer is the last proof.

Mockups: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, pages "Redesign: One thing (14 Nov)" and "Polish pass (15 Nov)" (sizes, states, text lengths and each corrected part, before and after; the Administrator, 2026-11-15). How the three concepts compared: [reviews/2026-11-14-window-redesign-proposals.md](reviews/2026-11-14-window-redesign-proposals.md). Sources of older rows: RADE = [docs/DECISIONS.md](DECISIONS.md); Z = [rhope-ops/90-161.Z docs/DECISIONS.md](https://github.com/rhope-ops/90-161.Z/blob/main/docs/DECISIONS.md).

## The idea

The window shows one statement or one question at a time (a "card"). It is quiet when things are fine and speaks only when it needs the person. Everything else is one key away, in the Record (F2). Each answer moves on: there is no Next / Back row and no Exit button.

## Fixed parts

| Part | Rule |
|---|---|
| Light | 6 px on the top edge. Yellow #FFD520 = RADE waits for you. Dark red #8B1A1A = FAILED, NEEDS REVIEW or STOPPED. Else off. The words on the card always say it too |
| Logo line | Logo K 40 px, the word RADE 15 pt bold navy, then the chosen application and version in gray. The tagline "Test and deploy apps for your organization" is in the title bar |
| Card | One block: its left edge at 12 % of the width, 40 % of the spare height above it. Parts, top to bottom, each shown only when the card names it: a line in capitals, the sentence (Segoe UI Semibold 22 pt, navy), up to 4 paragraphs (11 pt), the choices, the numbered lines of a hand step, the step line with its bar and the last log line, a box with its label, the error box, two file links, a note, the help line (13.5 pt), up to 5 buttons, a last gray line, the owner's test extras. The buttons, the last gray line and the test extras are always in view: when a card is taller than the window, only the parts above the buttons scroll |
| Bottom line | "Record (F2)" and "Back" as links on the left; on the right one gray text (progress, time, state). As tall as the links with their margin and focus ring, 46 px at least (R24: at 150 % a fixed 46 cut "Record (F2)" by 1 px) |
| Bottom edge | The bar for all steps, 4 px, Air Force blue; green when a run passed. The bar for this step is 200 x 4 px beside the step name |
| Size | 1020 x 760 at 100 % scaling; at most 95 % of the screen; no minimum size (a scaled minimum could be taller than a small screen). Text and rows of buttons wrap at the card's width, and no box is wider than the card. Nothing scrolls at 1020 x 616 and larger, except the log box and a long list in the Record; in a smaller window (1280 x 800 at 150 % gives 811 x 469) the text of a tall card scrolls above its buttons. The window has its own taskbar button and a minimize box: it runs as the main form of its thread with no owner (ShowDialog only when a message loop already runs there), so it can be restored after it is minimized, and RADE restores it when it needs the person (R24) |

Colors, one meaning each: navy #0B2545 = text and focus; Air Force blue #00539F = the action and progress; yellow = your turn; dark red = failed and the one destructive action (Uninstall); green #2E8540 = passed; gray #5A6573 = second lines. Buttons: primary blue with white bold text; others white with a gray edge (#7A8794); not available = gray (#E9ECF0, text #555555, drawn by RADE so that Windows does not gray the text again). Under the pointer a white button is #E3E8EE and while pressed #E9ECF0; a blue or dark red button keeps its color. "Uninstall" while it is not available: gray with dark red text and edge; when it is built: dark red with white text. Links are blue, bold and underlined. Focus is a 2 px navy ring around the control that has it, also after a mouse click, also on the Record's step boxes and text box.

## Sizes

One place in the engine: `$ui.Z` (pixels at 100 % scaling). The [RADE page](../index.html) uses the same button size and gap (the Administrator, 2026-11-15). One scale source (R24): the window's parts are made at 100 % and Windows Forms scales them with the form; every size RADE sets or draws after that (the choices, the Record's list and step boxes, margins set per card, box widths, bars, scroll steps) goes through `$ui.Sc`, which uses the dpi the form scales to (its auto-scale dimensions). The screen dpi (`Graphics.DpiX`) is only reported: on the R24 device it said 96 while the form scaled 1.5 x. A button grows with its text and shrinks back for the next card (AutoSize, grow and shrink; R24: a long answer choice kept three buttons wide on Done).

| Part | Size |
|---|---|
| Action button (a card's buttons; every button of the page) | 132 x 40 at least; it grows with its text |
| Compact button (beside a box; the Record's "Back") | 110 x 30 at least |
| Link | 28 high, bold, underlined |
| Choice (Choose) | 66 high, or as tall as its lines |
| Between two buttons or two links | 8 |
| "Uninstall" | alone at the right end of the row; when the row wraps, on its own row at the left edge |
| Gaps above a card part | 4 (sentence, second paragraph), 8 (last log line, box row, error box, note), 12 (first paragraph, hand-step lines, step line), 16 (help line, buttons), 24 (choices, last gray line, test extras) |
| Page only | button corners 3 px |

Alignment (the Administrator, 2026-11-15, after the R24 pictures; [DECISIONS.md](DECISIONS.md)):

- **One midpoint per row.** The header (logo, the word RADE, the application) and each label-box-button row (the hand step's "Address", the site card's "Site address", the question card's "Your answer", the test extras) share one vertical midpoint: each part's top margin comes from the tallest part. A row that wraps (the test extras in a small window) is aligned line by line. A one-line box is a frame exactly as tall as the compact button beside it (measured, so one value drives both) with RADE's own 1 px edge; the text box inside fills the frame less 6 px on each side and sits in its middle. Label to box and box to button are 8 apart. The It-failed card's error box has no label or button beside it.
- **One left edge per card.** Where the ink starts (the text of the line in capitals, the headline or the tick on Done, the body, the row labels, the first link, the help and last lines) and the edge of the first button, the first choice and the error box are on one edge, 10 px into the card's column. Each part's ink start is measured on Windows (the part drawn into a bitmap: its own text flags, padding and the first letter's side bearing) and its margin moves it there (`$ui.Ink`, `$ui.FitEdges`).
- **One border.** Every button (action, compact, link) draws its own face, its 1 px edge and its text in every state (normal, under the pointer, pressed, focused, default, not available), over what Windows drew: no theme border, no black default-button border, no dotted focus rectangle. A choice on Choose draws a 1 px gray edge, and 2 px navy when it has the focus. Focus is the 2 px navy ring the parent draws. Check boxes and the multi-line boxes (the error text, the Record's log) keep the Windows look.
- **Question headline** (the Administrator, 2026-11-15: rework B). The prompt's first sentence (up to the first "?", "." or ":" followed by a space or the end) is the headline at 22 pt; the rest is a body line under it; a one-sentence prompt has no body line. A first sentence too long for one line shrinks to fit: in 0.5 pt steps to 60 % (13.2 pt; never under the body size, 11 pt), and only at that size does it wrap (a choice of the orchestrator). It fits again when the window changes size. At 13.2 pt about 62 characters fit on one line in the smallest window (811 x 469) and about 81 at 1020 x 760. Other cards keep the headline size.

## Text lengths

The most characters of each text an application gives the window. Source of the numbers: `TEXT_LIMITS` in [engine/rade_build.py](../engine/rade_build.py) (a test keeps this table equal to it). They come from the real font, measured in the window by the Windows job (Segoe UI 10 pt = 6.8 px for each letter, 12 pt bold = 8.3, 22 pt semibold = 14.9), and the narrowest card (604 px). In this release a longer text is a WARNING line of the build and a note of the app check (`scripts/check_apps.py`), not a failure (the Administrator, 2026-11-15); the window never cuts a part off, whatever the length.

| Text (manifest) | Limit | When longer, the window |
|---|---|---|
| application name | 48 | ends it with "..." on Choose and the logo line; wraps it in a sentence |
| version | 14 | ends it with "..." |
| summary | 150 | wraps it to 2 lines on Choose, then "..." |
| step name | 56 | wraps it as the sentence of a hand step and in the Record; in the step line the bar goes to the next line |
| step note | 200 | wraps it in the Record (the step list scrolls) |
| guide line | 160 | wraps it |
| doneText | 24 | the button grows with the text and the row wraps |
| step help | 160 | wraps it |
| answer prompt | 120 | wraps it as the sentence of its question card. A hard limit: a longer prompt stops the build and the schema check |
| answer choice | 40 | the button grows with the text and the row wraps. A hard limit, as the prompt |

RADE's own texts follow the same rule: a text the window draws wraps to 2 lines at most and then ends with "...", or its row wraps.

## Proof

| What | Where | Proves |
|---|---|---|
| Layout self-check | the engine (`$ui.Check`), in a test round and in the Windows job; a deploy does not run it | For each card shown: no text needs more room than its control has, no parent cuts a control, no two parts overlap, the parts of each line of an aligned row share one midpoint within 1 px (scaled) and a box is as tall as the button beside it, and the ink of every part of the card's column starts within 1 px of one edge, measured where the ink starts, not at the control's box ("Alignment"), and no word of a label that wraps is wider than the label (a cut word). It measures controls only: text that RADE draws itself (the choices on Choose, the check list of the Record) wraps or ends with "..." by its drawing rule and is not measured, and a part inside a scrolling text is not tested for a cut. Under "Window: OK" in the results e-mail draft: "Layout self-check: PASS layout, N cards (width x height at scale)" or the defects, then one line of scaling facts, numbers only: "SCALE dpiX=<screen dpi> deviceDpi=<the form's dpi, or n/a before .NET 4.7> mode=<AutoScaleMode> asd=<AutoScaleDimensions, w>x<h> autoScale=<CurrentAutoScaleDimensions, w>x<h> font=<form font height in px> fontPt=<form font size in points> aware=<PerMonitorV2, not-PerMonitorV2 or n/a: the process dpi awareness as Windows Forms reads it> screen=<w>x<h> work=<w>x<h> client=<w>x<h> state=<Normal, Minimized or Maximized> logo=<w>x<h> btn=<w>x<h>". logo and btn are the drawn logo and the first button of the card in screen pixels (40 x 40 and at least 132 x 40 at 100 %): direct measures of the scale that reached the screen. The scale in the first line is the form's (the one scale source, "Sizes"); when the screen dpi says another, it is named beside it ("at 150 % (the form auto-scale; the screen dpi says 100 %)"; R24) |
| Windows job | [.github/workflows/window.yml](../.github/workflows/window.yml) with [tests/window_real.py](../tests/window_real.py): each pull request that changes the engine or the tests | Draws the real window of the sample bundle on Windows PowerShell 5.1 in 6 runs at 3 sizes (as the engine sets it on the runner's 1024 x 768 screen: 973 x 684; 1020 x 616; 811 x 469), two of them with every text at its limit, keeps one picture of each card, and fails on a layout defect, on a card that scrolls above 811 x 469, on a picture that was not drawn, on a missing SCALE line, when the Maintenance card did not show, or when the question cards were not drawn: NN-answer-yesno.png, NN-answer-pick.png and NN-answer-text.png in the first run, and NN-answer-text.png in each run in the smallest window (the long-text run gives the text question one long first sentence, so its headline shrinks and wraps there). The runner has 100 % scaling only: 150 % is tested as the same size in 100 % pixels. A run that draws at 150 % is not possible there: the screen dpi changes only after a sign-in, and forcing the form's auto-scale dimensions scales the controls but not the fonts, so it would not be a 150 % picture. The stand-in tests (tests/engine_test.sh "window" 5) check that what RADE sizes itself follows a 1.5 x form with a 96 dpi screen |
| Work computer | a test round | The same self-check at the real scaling, and the person's "The window displayed correctly" box |

## Cards

| Card | Shows | Engine function or data |
|---|---|---|
| Boot | "Checking this computer." The Local checks of every application in the paste run once (base checks before Choose). Their PASSED results are used for the chosen application, except Word, disk and write, which run again | `$ui.RunBase`, `Get-CheckToRun`, `Invoke-Check` |
| Choose | One button per application: name, version, summary; steps, time and checks; for a deploy what is installed; a notice when a newer version is on the RADE page, with the link "Open the RADE page" (test and deploy). The name gets its width first; the two facts stay on the right when they fit beside it, else they go on one line under the summary. Keys 1 to 9 choose. None is chosen for you. An application with a FAILED Local check is not a button: a red cross, the reason, "What to do" on its own line, and FAILED; "Check this computer again" then shows. A newer round (test) is a paragraph; the last round is the gray line | `$apps`, `Get-AppFact`, `Get-InstalledText`, `Get-NewerVersion`, `Get-NewerRound`, `Get-LastRoundText`, `Select-App` |
| Maintenance | For an application that is installed: name, installed version and date; "Update to <version>" or "Repair" (it goes on to the checks); Diagnose, Back up, Restore and Uninstall are shown off (no engine function yet), Uninstall alone at the right end of the row with dark red text and edge. Mockups for Restore and Uninstall are on the canvas | `Read-Installed`; [engine.md "Maintenance run types"](engine.md#maintenance-run-types) |
| Site | "Which site does the application go to?" with one box, when a check needs the address and none is saved | `Get-SiteUrl`, `Test-SiteUrl`, `Save-SiteUrl` |
| Checking | The name of the check that runs; the bottom bar counts the checks | `Invoke-Check`, `Save-CheckCache` |
| A check failed (red) | The first FAILED check: its name, what was found, "What to do"; "Run checks again" (a sign-in or look-and-answer check that failed has its own button instead); "Change the site address" when the application has a site | `Get-CheckDef`, `$script:checkResults` |
| A check needs you (yellow) | The first check that waits: "Sign in and check site rights" (CAC) or "Check Power Automate" (you look and answer: Yes / No / Not now on a hand card) | `Invoke-Check` |
| Ready | "Ready to install <name> <version>." Then: where RADE writes and how many files are new, replaced or recycled; how many steps, the time, which step needs you; Word open; the first warning. "Install" (a test round: "Run") and "Steps and files" (the Record, where each step has its box). When the application needs a site: a gray last line "Site: <name>" (the last part of the saved address; on the card only, never in the log or the report) and "Change the site address" (the Administrator, 2026-11-15). OneDrive not found is its own red card | `Get-RoundPlan`, `Get-StepDefault`, `Get-StepWeight` |
| Run | "Installing <name>." with "Step k of n", the step name, its bar and count, the last log line, and when RADE needs you next. Bottom right: percent, and the time left only when earlier runs give one (R21 W6). A step that asks for a folder shows the Windows folder dialog before the run | `Invoke-Round`, `Get-Progress` |
| Your turn (yellow) | A step done by hand: its lines, the address (it can be changed; saved in Config), "Open in browser", the file path on the clipboard with "Copy file path" and "Show file in folder", then Done / It failed / Skip. "It failed" asks for the error text on its own card. Enter never answers this card | `Invoke-GuideStep`, `$script:guideUi` |
| A question (yellow) | After Done on a hand step that has questions (manifest `answers`; not after "It failed" or Skip): one card per question, in order. The line in capitals says "Step k of n · Question i of m", the prompt's first sentence is the headline and the rest a body line under it ("Sizes", "Alignment"). Yes / no: "Yes" and "No"; pick: one button per choice (the row wraps); text: the box "Your answer" (one line, 120 characters at most; empty is allowed) and "Continue". The answer buttons are all plain (none is the primary color), so no answer looks recommended; Enter answers only the text card (Continue). No Back. Their time counts into the step's time | `$ui.VAnswer`, `$script:guideUi`, `Invoke-GuideStep`; [engine.md "Step contract"](engine.md#step-contract) |
| Done | A green tick and "<name> <version> is installed." Nothing was sent; what the installs made, by kind. Close, "What it made" (the Record), "Open results folder", "Copy summary". A test round also shows the owner's test extras (results address, "Make e-mail draft", "The window displayed correctly") | `Get-InstalledText`, `Read-Installed`, `Save-RoundDraft` |
| Needs review (red) | The first step that needs review with its help line; that passed steps stay done; the help line with the Teams channel; "Copy summary" first | `Get-HelpLine`, the summary from `Invoke-Round` |
| Stopped (red) | Why the run stopped and what to do; the help line; "Copy the log", "Try again", Close | `Get-WhatToDo` |

The Record (F2, or its links): three columns. Checks by group (Local, Network, Access) with the result word in its own column: no name and no detail enters that column, and "fallback" goes under "PASSED" in gray. A name and each detail wrap to 2 lines at most. Under a check that did not pass, what was found and what to do; under a reused check, "Last check: DD-MM-YY" and, on the next row, what it found. This column scrolls only when it is taller than the window (Page Down, Page Up). Steps, each with a box (one line: a step name too long for the column ends with "...", shortened by RADE, so no tooltip shows; the full name is on the step's own card and in the box's accessible name; "needs you", "asks for a folder", its note or result; a Clean-up row when the bundle has one); the boxes can be changed only from Ready. One text box: each file as New, Replace or Recycle, the list of what the application's installs made, and the log.

## Rules that stay

| Rule | Source |
|---|---|
| No deploy unless every check passes: FAILED or NOT RUN blocks, WARNING does not; no "deploy anyway" | Z 2026-11-14 |
| Saved checks in RADE\Config\rade-checks.json; which are reused: [engine.md "Results"](engine.md#results) | RADE 2026-11-14 |
| The window uses the Windows profile folder and asks for no DODID | Z 2026-11-13 |
| The window's X asks first only while a step runs; closing stops the running step | Z 2026-11-14 (R17); no Exit button: RADE 2026-11-14 |
| All text a user sees is plain, simple English; screen names in "quotes", reported values in [brackets]; each problem has a "What to do" line | Z 2026-11-13, 2026-11-14 |
| Results: PASSED, PASSED (fallback), WARNING, FAILED, NOT RUN; the word is always shown, never color alone | RADE 2026-11-14 |
| RADE draws its own bars; no bar moves back inside a run or a step; still when Windows animations are off | Z 2026-11-14 (R17, R18) |
| A deploy sends nothing; a test round makes an Outlook draft that is never sent (fallback: folder and clipboard) | [engine.md "Deploy v1"](engine.md#deploy-v1); Z 2026-11-13 |
| No tooltips; AccessibleName on every control; every control by keyboard (Tab, Enter, F2 = Record, Page Down and Page Up = the Record's check list and the text of a card that is taller than the window, 1 to 9 = a choice; Esc = close the Record, else Back, and on Choose, which has no Back, it exits) | R21 W9; RADE 2026-11-14 |
| The same steps run as text when no window can open | Z 2026-11-13 |
| A card's buttons and choices take no click in the first 400 ms after the card shows (Enter and Space too): a double-click never answers the next card unseen. A word wider than its line (no space in it) is cut into pieces that fit, one per line, in the headline and in every body, help and last line: never clipped. The 400 ms count on a monotonic clock from the moment the card is on screen | Review of the R24 polish, 2026-11-15 |
| Card text is selectable: highlight part of a card, Ctrl+C or right-click Copy and Select All; same look as a label (read-only, borderless, no tab stop) | the Administrator 2026-11-17 |
| Start: after the checks pass, the Ready card has a Start button that opens the installed app; the update notice links the RADE page | the Administrator 2026-11-17 |
| The window keeps the size and place the user gives it (Windows Snap too) and opens there next time; text scales with the window at 125 % and 150 % | the Administrator 2026-11-17 |

Not in the window yet: bundle size in the summary, engine version and sha256 in the window, a JSON results block (RADE 2026-11-14, engine work row); the Maintenance actions other than Install.
