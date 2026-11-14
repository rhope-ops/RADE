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
| First screen stays minimal. | Built | Z 2026-11-14 (plain-English sweep) |

## Layout and brand

| Rule | State | Source |
|---|---|---|
| Layout B (side rail, 220 px, navy #0B2545 to Air Force blue #00539F, AF yellow #FFD520 edge), Wing Master Version II colors; preview https://claude.ai/artifact/SU4ghsQWy7EBzaLiZWNEMy. The rail holds the three screens as steps (this one in yellow bold) and the round and build. | Built (R18); first gov-device check is R18 "Window: OK" | RADE 2026-11-14 |
| Logo K (PNG in WinForms, 56 px from logo-K-128.png) replaces the yellow "RADE" circle; the word RADE to its right on the logo's midpoint; tagline "Test and deploy apps for your organization" below; one left edge. Master: [assets/logo](../assets/logo), yellow edge 2.8 units (K+2). | Built (R18) | RADE 2026-11-14 (logo K, layout B, edge rows) |
| Darker status-chip text in RADE only; 90-161.Z gets its own scheme later. | Not built | RADE 2026-11-14 |
| Primary buttons (Next, Run) Air Force blue with white bold text, navy on hover, gray when disabled. | Built (R18) | layout B preview |
| 1020 x 760 at 100 % scaling (minimum 680 x 540), Segoe UI 10, DPI scaling; rows in table layouts, no fixed positions. | Built | Z 2026-11-14; engine comments (R02) |
| Every check and step row is two lines high, so nothing moves while checks and steps run. | Built | Z 2026-11-14 (R17 window row) |

## Progress bars

| Rule | State | Source |
|---|---|---|
| Two bars: overall (weighted by expected seconds, with time left; Air Force blue) and this step ("PROGRESS n/m" lines, else time; AF yellow). | Built (colors R18) | Z 2026-11-14 |
| RADE draws its own bars (smooth fill, one soft light band); still when Windows animations are off. | Built | Z 2026-11-14 (R17 window row) |
| Both bars fill left to right; the back-and-forth block for a step with unknown progress is gone (the step bar follows time against the step's weight, at most 90 %). | Built (R18) | Z 2026-11-14 (R18 window row); the Administrator, 2026-11-14 |
| Neither bar moves back inside a run (overall) or a step (step bar). | Built | engine (R18) |

## Text and status

| Rule | State | Source |
|---|---|---|
| All text a user sees is plain, simple English; the log reads professionally. | Built | Z 2026-11-14 (two rows) |
| Check text: sentence case, screen names in "quotes", reported values in [brackets]. | Built | Z 2026-11-14 (no-deploy row) |
| Results: PASSED, PASSED (fallback), WARNING, FAILED, NOT RUN; one meaning per color and the word always shown (dark green, saddle brown, dark red, dim gray; running navy; all at least 4.5:1). | Built except PASSED (fallback) | RADE 2026-11-14 (engine); engine Get-CheckColor |
| Each problem has a "What to do" line under it. | Built | Z 2026-11-13 (R06 row) |
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
