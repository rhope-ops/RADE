# R21 window notes (the Administrator, 15 Nov 26)

Source: the Administrator's notes after 90-161.Z round R21 (engine pinned at eb561ce, layout P1; the round e-mail said "Window: NOT OK"). Status: **addressed in code by the "One thing" redesign** (built 14 Nov 26, docs/window-design.md; not verified on a device; W4 still needs the 90-161.Z task-script change). Before that: **documented only** (the Administrator, 15 Nov 26: "for these visual cleanups, make a note for another session to handle it. just document for now"). A separate session builds them as one UI pass, with a preview first (UI change: the Administrator approves before merge) and the measured checks in 90-161.Z `.claude/skills/ui-verify/SKILL.md`.

| # | Note (the Administrator's words, shortened) | Where it lives (agent finding) | Proposed direction (agent REC, not decided) |
|---|---|---|---|
| W1 | The new UI made the left-rail step text Choose / Check / Deploy look worse. | Rail step labels, layout B rows in docs/window-design.md. | Compare the R18 rail (approved) with P1 at 100 % and 150 %; restore the R18 font, weight and spacing unless P1 needed the change. |
| W2 | "The window displayed correctly" was cleared because a line appeared under it. | `$okBox` (engine/rade_build.py, about line 1652) and the hairline / log area below it. | Find the line (likely the log toggle redraw, W8); give the check box its own row with no border under it. |
| W3 | More "press Enter or select Next" text everywhere; it distracts. | `$setHint` calls (about lines 1785, 1810, 1889) and the Read-Host fallbacks. | One short hint per screen, only where the next action is not obvious; never repeat the button name. Enter still works. |
| W4 | The site is entered on the Check screen, then a "Address of the test site" popup asks again. It should use the site picked on Check and say that this is where the payload goes. The popup is ugly and not in RADE's style. | Not RADE: the 90-161.Z task scripts (T18 r2 and T19 r2 `Get-SiteAddress`, a VisualBasic InputBox every run) read the same Config\90161Z-site.txt that the Check screen saves. | RADE passes the site to each step (for example `-Site`, or the script reads Config without asking when `-NoPause` is set); the Check screen labels the box "Destination site (the round writes here)". The InputBox stays only for a script run by hand. Needs a 90-161.Z task-script change too. |
| W5 | The mini-instructions panel (guide step, for example T18) is too narrow: make it 1/4 to 1/3 wider; it opens scrolled to the bottom and must be scrolled up. | Guide window (`Invoke-GuideStep`, about line 492; window size and text box). | Width x 1.3 (inside the screen's working area); scroll the text to the top (SelectionStart 0, ScrollToCaret) when it opens. |
| W6 | Do not show "(a guess: no earlier runs)"; show the last run time only when there is data. | `Format-Duration` callers, about lines 1145, 1151, 1170, 1783. | No history: show no time note at all (the step estimate stays as "about N min" in the plan). History: "last run took N min". |
| W7 | The loading bars still do not match option B ("chill"). | Progress bars (docs/window-design.md "Progress bars"; drawn bars). | Re-read option B in the P1 proposal (https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld) and match it exactly: height, track, colors, label rows. Measure against the preview. |
| W8 | "Show log / Hide log" does nothing but cause a visual bug; likely the line in W2. | `$logLink` (about lines 1634-1643): auto-hide below 80 px fights the manual toggle. | Remove the link: the log is always shown in the space left (or always in a fixed area); the full log is in the results folder. |
| W9 | Remove the hover tooltips: they are formatted badly, cover the view and are not needed. | `$tips` ToolTip (about lines 1426, 1456, 1799) and the grid `ToolTipText` (about line 1230). | Remove every tooltip; keep AccessibleName for screen readers. Text cut with "..." stays readable in the log and the details line. |
| W10 | Do not let columns be resized by hand. | Grids (about line 1305: rows are fixed, columns are not). | `AllowUserToResizeColumns = $false` on every grid; set the column widths in code. |

## Related question from the same notes

- **Pre-check before an app is selectable** (the Administrator's idea): decided 14 Nov 26 (docs/DECISIONS.md "base checks before Choose, app checks after"; docs/engine.md "Check stages" 1: "An app whose checks cannot pass is marked on the Choose screen"). **Not built**: docs/window-design.md says "Partly built (all checks run after Choose)". It belongs in the same pass or the one after it: run the base checks when the window opens, then mark or disable an app card whose needs cannot pass, with the reason on the card.

## UI pass 3 proposals (14 Nov 26, evening)

Mockups: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld, page "UI pass 3" (15 artboards, 1020 x 760: Choose, Check, Deploy running, Deploy done, by-hand step panel and parts, for each proposal). Status: **not chosen** (the Administrator, 14 Nov 26: no preference yet; the build waits for the Administrator's prompt). Decided the same day: [DECISIONS.md](../DECISIONS.md) 2026-11-14 "UI pass 3". All three build W1-W10 and the pre-check before Choose.

| | A Refine | B Quiet (agent REC) | C Command |
|---|---|---|---|
| Shell | 220 px rail, flat navy, yellow edge, step text as in R18 | Rail, flat navy, no edge; a yellow tick marks this screen | No rail: a 56 px navy band; navy window |
| Check rows | Two lines, tinted chip | One line (30 px), mark + word; one "Needs you" list holds the finding, what to do and the button | As B (28 px); the title is the status |
| Deploy | "58 %" block as option B (W7), 8 px blue and 4 px green bars | One number, one 6 px bar; the step bar is in the running row | As B, yellow bar on navy |
| Decisions it changes | Rail gradient only | Two-line rows, chips, two labelled bars and the green step bar, yellow rail edge | Those of B, plus the side rail, the white main area and the blue primary button |
| Check height at 150 % (body 536; C 480) | 521 | About 503 with 4 items in "Needs you" | About 473 with 4 items |
| Risk | A long finding is cut with "..." and has no tooltip | A fifth "Needs you" item scrolls the list | WinForms has no dark theme: scroll bars, system dialogs and check box glyphs stay light unless RADE draws them |
| Engine work (agent estimate, low confidence) | Small | Medium | Large |

Measured on the mockups in Chromium at 1020 x 760 (14 Nov 26; not on a device, fonts differ from Segoe UI): 0 clipped texts, 0 parts outside the window, 0 targets under 24 x 24 px, lowest text contrast 5.55:1 (A, B) and 7.58:1 (C). The heights above are arithmetic, not measured on a device.
