# RADE window design

Status: the one place for the RADE window's UI decisions (the Administrator, 2026-11-14: consolidate them). Each row cites the decision; the decision text itself stays in its decisions table. Built in [engine/rade_build.py](../engine/rade_build.py) (WinForms, Windows PowerShell 5.1). "Built" = in the R18 bundle; "Not built" = decided, waiting for its build.

Sources: RADE = [docs/DECISIONS.md](DECISIONS.md); Z = [rhope-ops/90-161.Z docs/DECISIONS.md](https://github.com/rhope-ops/90-161.Z/blob/main/docs/DECISIONS.md).

## Screens and flow

| Rule | State | Source |
|---|---|---|
| One window, three screens: 1 Choose the application, 2 Check, 3 Deploy. The catalog is embedded in the paste (no fetch). | Built | Z 2026-11-14 ("Deployer window: Choose app > Check > Deploy") |
| Base checks before Choose; app checks (each step's `needs`) after an app is chosen. | Partly built (all checks run after Choose) | RADE 2026-11-14 (engine), [engine.md](engine.md) |
| No deploy unless every check passes: FAILED or NOT RUN blocks, WARNING does not; no "deploy anyway". | Built | Z 2026-11-14 |
| Saved checks in RADE\Config\rade-checks.json: fast checks fresh, slow checks reused 7 days. | Built as 7 days for all; split not built | RADE 2026-11-14 (saved checks) |
| Enter (or Run) starts the run; the window uses the Windows profile folder and asks for no DODID. | Built | Z 2026-11-13 (R03, R04 rows) |
| Exit button; it asks first only while a step runs. | Built | Z 2026-11-14 (R17 window row) |
| First screen stays minimal. No application is selected when the window opens; Next stays off until one is chosen. | Built (engine, PR); first check is the next round's "Window: OK" | Z 2026-11-14 (plain-English sweep); RADE 2026-11-14 (UI pass P1) |

## Layout and brand

| Rule | State | Source |
|---|---|---|
| Layout B (side rail, 220 px, navy #0B2545 to Air Force blue #00539F, AF yellow #FFD520 edge), Wing Master Version II colors; preview https://claude.ai/artifact/SU4ghsQWy7EBzaLiZWNEMy. The rail holds the three screens as steps (this one in yellow bold) and the round and build. | Built (R18); first gov-device check is R18 "Window: OK" | RADE 2026-11-14 |
| Logo K (PNG in WinForms, 56 px from logo-K-128.png) replaces the yellow "RADE" circle; the word RADE to its right on the logo's midpoint; tagline "Test and deploy apps for your DoD organization" below (DoD added: the Administrator, 2026-11-14); one left edge. Master: [assets/logo](../assets/logo), yellow edge 2.8 units (K+2). | Built (R18) | RADE 2026-11-14 (logo K, layout B, edge rows) |
| Main area: layout A "Quiet table" (proposals https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld). White main area; title (Segoe UI Semibold 15, navy) and one gray line on each screen; borderless grids with row lines only and bold gray headers; Check column = small gray group over the name; Result and step Status = tinted chips with the word; counts as "12 passed", zero counts hidden; check buttons secondary (white, gray border), "Run checks again" a link; one hairline over Next, Back and Exit. Deploy: "Writes to" and the path, then both bars right under it, then the steps (Run, Step, Status); log visible with Hide log. Choose: the same style; the last round under the title. Layout P1 changes Choose, Check and Deploy as in "Layout P1" below. | Built (engine 2026-11-14, R20 bundle); P1 built (engine, PR) | RADE 2026-11-14 (layout A row); RADE 2026-11-14 (UI pass P1) |
| Darker status-chip text in RADE only; 90-161.Z gets its own scheme later. | Not built | RADE 2026-11-14 |
| Primary buttons (Next, Run) Air Force blue with white bold text, navy on hover, light gray (#E9ECF0, text 6.3:1) when disabled. Next, Back, Exit and Run are one size: 132 x 34 px, whatever the text. Run takes Next's place at the bottom right. | Built (R18; engine fix 2026-11-14); Run place: P1 | layout B preview; the Administrator, 2026-11-14 (size, lighter disabled); RADE 2026-11-14 (UI pass P1) |
| 1020 x 760 at 100 % scaling (minimum 680 x 540), Segoe UI 10, DPI scaling; rows in table layouts, no fixed positions. | Built | Z 2026-11-14; engine comments (R02) |
| Every check and step row is two lines high, so nothing moves while checks and steps run. | Built | Z 2026-11-14 (R17 window row) |
| No scroll and no clipping at 100 % and at 150 % on 1920 x 1080 (main body 680 and 536 px): pixel budget in "Layout P1". | Built (engine, PR); not verified on a device | RADE 2026-11-14 (UI pass P1) |

## Progress bars

| Rule | State | Source |
|---|---|---|
| Two bars: overall (weighted by expected seconds, with time left; Air Force blue) and this step ("PROGRESS n/m" lines, else time; green #2E8540, the Administrator 2026-11-14). Overall 8 px, step 4 px, rounded ends, no border, track #EEF1F5; one line over each bar (what on the left, how far on the right). | Built (colors R18); sizes and labels: P1 | Z 2026-11-14; RADE 2026-11-14 (UI pass P1) |
| RADE draws its own bars (smooth fill, one soft light band); still when Windows animations are off. | Built | Z 2026-11-14 (R17 window row) |
| Overall bar Air Force blue; step bar green #2E8540 (the Administrator, 2026-11-14). Both bars fill left to right; the back-and-forth block for a step with unknown progress is gone (the step bar follows time against the step's weight, at most 90 %). | Built (R18) | Z 2026-11-14 (R18 window row); the Administrator, 2026-11-14 |
| Neither bar moves back inside a run (overall) or a step (step bar). | Built | engine (R18) |

## Text and status

| Rule | State | Source |
|---|---|---|
| All text a user sees is plain, simple English; the log reads professionally. | Built | Z 2026-11-14 (two rows) |
| Check text: sentence case, screen names in "quotes", reported values in [brackets]. | Built | Z 2026-11-14 (no-deploy row) |
| Details lines: one fact per line, no full stop, never joined with ";"; a reused check reads "Last check: DD-MM-YY" over what it found. Column headers bold. Window (P1): the group is a heading over its checks; a check row shows its details on one line, the facts joined by a middle dot, cut with "..." to fit; the full lines are in the tooltip, the log and the e-mail. | Built (engine 2026-11-14, R20 bundle); window line: P1 | RADE 2026-11-14 (text and grid row); RADE 2026-11-14 (UI pass P1) |
| All text (window, guides, step notes, flow inputs) is professional and polished; formatted where the control allows. | Partly built (engine texts 2026-11-14; step notes and flow inputs per round) | RADE 2026-11-14 (text and grid row) |
| Results: PASSED, PASSED (fallback), WARNING, FAILED, NOT RUN; one meaning per color and the word always shown (dark green, saddle brown, dark red, dim gray; running navy; all at least 4.5:1). | Built except PASSED (fallback) | RADE 2026-11-14 (engine); engine Get-CheckColor |
| Each problem has a "What to do" line under it (window P1: after the finding on the row's second line). | Built | Z 2026-11-13 (R06 row) |
| A check that needs you (sign-in, look and answer) has its link in its own row: "Sign in and check site rights", "Check Power Automate". "Run checks again" is a link right of the counts. | Built (engine, PR) | RADE 2026-11-14 (UI pass P1) |
| One hint left of the nav buttons on every screen says what to do next, colored by meaning (gray, or the result colors). | Built (engine, PR) | RADE 2026-11-14 (UI pass P1) |
| Short names in the window for 3 checks: "The SharePoint tool (PnP 1.12.0) is installed", "You can change the site (CAC sign-in)", "You can import flows (you look)"; the log and the e-mail keep the full names. | Built (engine, PR) | RADE 2026-11-14 (UI pass P1) |
| The real path is on screen in bold ("Writes to"); before Run the window lists every file as New, Replace or Recycle. | Built | Z 2026-11-13 (R06 row) |

## Steps done by hand

| Rule | State | Source |
|---|---|---|
| A by-hand step (for example a flow import) opens a normal, minimizable window at the right edge of the screen (never always-on-top), with numbered steps, Open in browser (address editable, remembered in Config) and the file path on the clipboard. | Built | Z 2026-11-14 (R13, R14) |
| Buttons: Done / It failed / Skip. It failed takes the error text from a box; the e-mail line reads FAILED with the masked text. A skipped step expects no result files. | Built (R18) | Z 2026-11-14 (R18 window row); the Administrator, 2026-11-14 |
| A check done by eye has Yes / No / Not now. | Built | engine (Power Automate check) |

## Results e-mail

| Rule | State | Source |
|---|---|---|
| One results folder Rounds\<round> of plain files (no zip); an Outlook draft with subject PASSED or NEEDS REVIEW, never sent; fallback: folder plus clipboard. | Built | Z 2026-11-13 (usability bar, R05, R06) |
| "Window: OK" box: the user says whether anything overlapped or was cut off. | Built | Z 2026-11-13 (R06 row) |
| Not built yet (after R17): bundle size in the summary, hash-pinned engine (version + sha256 in the window), JSON results block. | Not built | RADE 2026-11-14 (engine work row) |

## Layout P1 (the Administrator, 2026-11-14)

Mockups: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld (row P1). Audit and the rejected P2: [reviews/2026-11-14-window-ui-audit.md](reviews/2026-11-14-window-ui-audit.md). Sizes are at 100 % scaling (logical px); the window scales them.

| Part | Spec |
|---|---|
| Type scale | Word mark 20 pt bold; title Segoe UI Semibold 15 pt navy; rail steps 11 pt (this screen bold); body 10 pt; labels, buttons, headers, step names 10 pt bold; secondary lines, hints, group headings 9 pt (headings bold, capitals); chips 8.5 pt bold; log Consolas 9 pt |
| Colors | Navy #0B2545; AF blue #00539F (primary, links, selection, overall bar); yellow #FFD520 (rail edge, this screen); green #2E8540 (step bar); ink #1B2430 (15.6:1); secondary text #5A6573 (5.9:1); control edge #7A8794 (3.7:1); card edge #C9D2DC; hairlines #E3E8EE, row lines #EEF1F4; bar track #EEF1F5; selected card #F3F8FD; newer-round box #8B1A1A with white text (9.3:1); result colors: Get-CheckColor in the engine |
| Spacing | Scale 4, 8, 12, 16, 24. Main area: 24 left and right, 20 top (the logo's top), 14 bottom; 12 between blocks; 24 between the check columns; 16 between check groups |
| Buttons | All 34 high. Primary and nav 132 wide; secondary (white, #7A8794 edge) at least 132; links AF blue, bold, underlined, 28 high (24 in a check row) |
| Rail steps | 22 px circle: this screen = yellow fill, navy number, yellow bold name; done = white ring, check mark, white name; later = mist ring and number |
| Choose | One card per app, 72 high + 8 gap, radius 6: radio (18 px; ring #5A6573, selected AF blue with a dot), name bold, facts and summary 9 pt; selected = 2 px AF blue edge + #F3F8FD. Nothing selected on open; Next off until a choice |
| Check | Site address row (label and box on one line). Two columns: the first group (Local) left, the others right. Group heading 24; row 40 (name / details), 64 with a link; chip column 84 at the right. Counts and "Run checks again" under the columns |
| Deploy | "Writes to" + path (10 pt, path bold); overall line + 8 px bar; step line (9 pt) + 4 px bar; steps grid, rows 44; log (hides itself below 80 px; "Show log"); "Results to"; "Window" check box with the result buttons, which show at DONE |
| Nav | Hairline, then the hint (9 pt, up to 2 lines) on the left and Exit, Back, Next or Run on the right; Tab reaches the primary first |

Pixel budget (main body: 680 at 100 %; 536 at 150 % on 1920 x 1080, where the window is cut to 95 % of the screen):

| Screen | Height | Spare at 100 % / 150 % |
|---|---|---|
| Choose | 57 + 80 per app | 2 apps: 463 / 319; no scroll up to 7 / 5 apps |
| Check (14 checks, site row) | 57 + 40 + 384 (Local: 24 + 9 x 40) + 40 = 521; right column 24 + 120 + 16 + 24 + 2 x 64 = 312 | 159 / 15 |
| Deploy | 60 + 83 + 26 + 44 per step + log (80 or more) + 40 + 46 | 3 steps: 213 / 69; the log hides above 7 / 4 steps |

Below the budget (1280 x 800 at 150 %: body about 364) the check columns scroll and the log hides; nothing is cut off. Not verified on a device until the next round's "Window: OK" line.
