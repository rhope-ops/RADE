# RADE window design

Status: the one place for the RADE window's UI decisions (the Administrator, 2026-11-14: consolidate them). The window is the "One thing" design (the Administrator, 2026-11-14, [DECISIONS.md](DECISIONS.md)); it replaced layout B, layout A, layout P1 and the UI pass 3 proposals. Built in [engine/rade_build.py](../engine/rade_build.py) (WinForms drawn in code, Windows PowerShell 5.1); the window code is the part from `function Get-AppFacts` to the text-mode block. **Not verified on a device**: its logic runs in [tests/engine_test.sh](../tests/engine_test.sh) (section "window") against stand-in types; what it looks like is checked first by a round on a work computer.

Mockups: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, page "Redesign: One thing (14 Nov)". How the three concepts compared: [reviews/2026-11-14-window-redesign-proposals.md](reviews/2026-11-14-window-redesign-proposals.md). Sources of older rows: RADE = [docs/DECISIONS.md](DECISIONS.md); Z = [rhope-ops/90-161.Z docs/DECISIONS.md](https://github.com/rhope-ops/90-161.Z/blob/main/docs/DECISIONS.md).

## The idea

The window shows one statement or one question at a time (a "card"). It is quiet when things are fine and speaks only when it needs the person. Everything else is one key away, in the Record (F2). Each answer moves on: there is no Next / Back row and no Exit button.

## Fixed parts

| Part | Rule |
|---|---|
| Light | 6 px on the top edge. Yellow #FFD520 = RADE waits for you. Dark red #8B1A1A = FAILED, NEEDS REVIEW or STOPPED. Else off. The words on the card always say it too |
| Logo line | Logo K 40 px, the word RADE 15 pt bold navy, then the chosen application and version in gray. The tagline "Test and deploy apps for your organization" is in the title bar |
| Card | One block: its left edge at 12 % of the width, 40 % of the spare height above it. Parts, top to bottom, each shown only when the card names it: a line in capitals, the sentence (Segoe UI Semibold 22 pt, navy), up to 4 paragraphs (11 pt), the choices, the numbered lines of a hand step, the step line with its bar and the last log line, a box with its label, the error box, two file links, a note, the help line (13.5 pt), up to 5 buttons, a last gray line, the owner's test extras |
| Bottom line | "Record (F2)" and "Back" as links on the left; on the right one gray text (progress, time, state) |
| Bottom edge | The bar for all steps, 4 px, Air Force blue; green when a run passed. The bar for this step is 200 x 4 px beside the step name |
| Size | 1020 x 760 at 100 % scaling; at most 95 % of the screen; no minimum size (a scaled minimum could be taller than a small screen). Text wraps at the card's width; nothing scrolls except the log box and a long step list in the Record |

Colors, one meaning each: navy #0B2545 = text and focus; Air Force blue #00539F = the action and progress; yellow = your turn; dark red = failed and the one destructive action (Uninstall); green #2E8540 = passed; gray #5A6573 = second lines. Buttons: primary blue with white bold text; others white with a gray edge (#7A8794); not available = gray (#E9ECF0, text #555555). Links are blue, bold and underlined. Focus is a 2 px navy ring around the control that has it, also after a mouse click.

## Cards

| Card | Shows | Engine function or data |
|---|---|---|
| Boot | "Checking this computer." The Local checks of every application in the paste run once (base checks before Choose). Their PASSED results are used for the chosen application, except Word, disk and write, which run again | `$ui.RunBase`, `Get-CheckToRun`, `Invoke-Check` |
| Choose | One button per application: name, version, summary; steps, time and checks; for a deploy what is installed; a notice when a newer version is on the app page. Keys 1 to 9 choose. None is chosen for you. An application with a FAILED Local check is not a button: a red cross, the reason, what to do, and FAILED; "Check this computer again" then shows. A newer round (test) is a paragraph; the last round is the gray line | `$apps`, `Get-AppFacts`, `Get-InstalledText`, `Get-NewerVersion`, `Get-NewerRound`, `Get-LastRoundText`, `Select-App` |
| Maintenance | For an application that is installed: name, installed version and date; "Update to <version>" or "Repair" (it goes on to the checks); Diagnose, Back up, Restore and Uninstall are shown off (no engine function yet), Uninstall set apart. Mockups for Restore and Uninstall are on the canvas | `Read-Installed`; [engine.md "Maintenance run types"](engine.md#maintenance-run-types) |
| Site | "Which site does the application go to?" with one box, when a check needs the address and none is saved | `Get-SiteUrl`, `Test-SiteUrl`, `Save-SiteUrl` |
| Checking | The name of the check that runs; the bottom bar counts the checks | `Invoke-Check`, `Save-CheckCache` |
| A check failed (red) | The first FAILED check: its name, what was found, "What to do"; "Run checks again" (a sign-in or look-and-answer check that failed has its own button instead); "Change the site address" when the application has a site | `Get-CheckDef`, `$script:checkResults` |
| A check needs you (yellow) | The first check that waits: "Sign in and check site rights" (CAC) or "Check Power Automate" (you look and answer: Yes / No / Not now on a hand card) | `Invoke-Check` |
| Ready | "Ready to install <name> <version>." Then: where RADE writes and how many files are new, replaced or recycled; how many steps, the time, which step needs you; Word open; the first warning. "Install" (a test round: "Run") and "Steps and files" (the Record, where each step has its box). OneDrive not found is its own red card | `Get-RoundPlan`, `Get-StepDefault`, `Get-StepWeight` |
| Run | "Installing <name>." with "Step k of n", the step name, its bar and count, the last log line, and when RADE needs you next. Bottom right: percent, and the time left only when earlier runs give one (R21 W6). A step that asks for a folder shows the Windows folder dialog before the run | `Invoke-Round`, `Get-Progress` |
| Your turn (yellow) | A step done by hand: its lines, the address (it can be changed; saved in Config), "Open in browser", the file path on the clipboard with "Copy file path" and "Show file in folder", then Done / It failed / Skip. "It failed" asks for the error text on its own card. Enter never answers this card | `Invoke-GuideStep`, `$script:guideUi` |
| Done | A green tick and "<name> <version> is installed." Nothing was sent; what the installs made, by kind. Close, "What it made" (the Record), "Open results folder", "Copy summary". A test round also shows the owner's test extras (results address, "Make e-mail draft", "The window displayed correctly") | `Get-InstalledText`, `Read-Installed`, `Save-RoundDraft` |
| Needs review (red) | The first step that needs review with its help line; that passed steps stay done; the help line with the Teams channel; "Copy summary" first | `Get-HelpLine`, the summary from `Invoke-Round` |
| Stopped (red) | Why the run stopped and what to do; the help line; "Copy the log", "Try again", Close | `Get-WhatToDo` |

The Record (F2, or its links): three columns. Checks by group (Local, Network, Access) with the result word and, for a check that did not simply pass, one line of detail. Steps, each with a box ("needs you", "asks for a folder", its note or result; a Clean-up row when the bundle has one); the boxes can be changed only from Ready. One text box: each file as New, Replace or Recycle, the list of what the application's installs made, and the log.

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
| No tooltips; AccessibleName on every control; every control by keyboard (Tab, Enter, F2 = Record, 1 to 9 = a choice; Esc = Back, and on Choose, which has no Back, it exits) | R21 W9; RADE 2026-11-14 |
| The same steps run as text when no window can open | Z 2026-11-13 |

Not in the window yet: bundle size in the summary, engine version and sha256 in the window, a JSON results block (RADE 2026-11-14, engine work row); the Maintenance actions other than Install.
