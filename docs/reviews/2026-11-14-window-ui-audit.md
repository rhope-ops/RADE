# RADE window: UI audit and pixel budget (2026-11-14)

Scope: the 3 screens in [engine/rade_build.py](../../engine/rade_build.py) (Choose, Check, Deploy) as built for 90-161.Z R20. Approved rules: [docs/window-design.md](../window-design.md). Mockups P1 and P2: https://claude.ai/artifact/M2EKZCrkUtYshuFGq746Ld (rows "P1" and "P2" above the A, B, C rows). Status: proposal; nothing built. The Administrator picks P1 or P2.

All sizes are logical pixels (100 % scaling). Line heights: Segoe UI 10 pt = 19, 9 pt = 16, Semibold 15 pt = 27.

## 1. Audit

| # | Element | Now | Problem | Fix (P1 and P2 unless noted) |
|---|---|---|---|---|
| G1 | Window height at 150 % | Client 1020 x 760; Form.Shown cuts the form to 95 % of the work area | On 1920 x 1080 at 150 % the client is about 1020 x 616: the main body loses 144 px, so lists clip or scroll | Budget every screen for a 536 px body (section 2) |
| G2 | Main-area padding | 26 left/right, 10 top + 14 title margin, 14 bottom | Title top (24) is not on the logo top (20); 26 is off the spacing scale | 24 left/right, 20 top, 14 bottom; spacing scale 4, 8, 12, 16, 24 |
| G3 | Font sizes | 9 sizes: 20 b, 15 sb, 11, 10, 10 b, 9.5, 9, 8.5, 8 b | Too many sizes; 9.5 and 8.5 next to 9 read as mistakes | 6 sizes: 20 b (word mark), 15 sb (title), 11 (rail steps), 10 and 10 b (body, labels, buttons), 9 (secondary lines, chips 8.5 b stay) |
| G4 | Button sizes | Nav 132 x 34; other buttons AutoSize, min 110 x 32 | Two heights (32, 34) side by side | Every button 34 high; secondary width = text + 28, at least 132 |
| G5 | Secondary border | #C9D2DC on white, 1.5:1 | Below 3:1 for a control edge (WCAG 1.4.11) | #7A8794, 3.7:1 (also input boxes) |
| G6 | Input boxes | TextBox Fixed3D, label in a FlowLayout, label 3 px lower | 3-D edge in a flat window; label and box out of line | BorderStyle FixedSingle; label and box in a 2-column table, both centered on the row |
| G7 | Rail steps | "1   Choose" with spaces; done = white, next = mist #DDE8F3 | White and mist look the same, so "done" is not visible; spaces align only in one font | Number in a 22 px circle: current yellow fill, done white ring with a check mark, later mist ring |
| G8 | Newer-round banner | A red label row above the screens | Takes 27 px from every screen; red on white only | A dark red box (#8B1A1A, white text 9.3:1) at the foot of the rail; no main-area height |
| G9 | Status / hint line | Check: own row under the counts; Choose and Deploy: none | One screen tells the user what to do, two do not | One hint at the left of the nav row on every screen (9 pt, 2 lines max), colored by meaning |
| G10 | Primary action place | Next bottom right; Run in a content row on Deploy | The primary button moves on screen 3 | Run takes Next's place (bottom right); one primary per screen |
| G11 | Tab order | Content, then Next, Back, Exit (right to left) | None (primary first is intended) | Keep |
| C1 | App list selection | SelectedIndex = 0 on Shown | The first app looks chosen before the user acts | No selection on open; Next disabled; hint "Select an application to continue" |
| C2 | Selected app row | Tint #E7F1FB on white (1.14:1); name navy vs ink | Selection nearly invisible | Radio circle (filled AF blue) + 2 px AF blue outline + tint |
| C3 | App list height | ItemHeight x max(2, n) + 2, in an AutoSize row | Too tall at high DPI (NEXT_PROMPT); no scroll | List in the fill row; scrolls only above 7 apps (100 %) or 5 apps (150 %) |
| C4 | Facts line | "3 steps   \|   about 6 min   \|   14 checks" | Pipe separators look like a table | "3 steps (1 needs you) · about 6 min · 14 checks before you deploy" |
| C5 | Summary | A label under the list, shown for the selection | With no selection it is empty space | P1: line 3 of each card. P2: "About <app>" under the table |
| K1 | Check table | One grid, 14 rows x 48 px = 672 + header | Needs a scroll at 100 % (about 10 rows show) | P1: two columns (Local 9 / Network 3 + Access 2), 40 px rows. P2: one table, 30 px single-line rows, group bands |
| K2 | "Sign in and check site rights", "Check Power Automate" | Secondary buttons next to the counts | Far from the rows they fill; look out of place | A link in the row it runs (line 2 of that row, 24 px high); reads "Check again" after a result |
| K3 | "Run checks again" | Flat button, 32 high | Next to bordered buttons, its style looks accidental | Link style, 28 high, right of the counts (the only link in that row) |
| K4 | Count labels | Fixed width "99 warnings" each | Uneven gaps when zero counts hide | 16 px gap between shown counts |
| K5 | Long check names | "The SharePoint tool (PnP.PowerShell 1.12.0) is installed" | Cut off in a narrow column | Shorter names (needs approval): "The SharePoint tool (PnP 1.12.0) is installed", "You can change the site (CAC sign-in)", "You can import flows (you look)" |
| D1 | Overall bar | 20 px, square, #767676 border | Not like the preview | 8 px, radius 4, no border, AF blue on track #EEF1F5 (6.8:1) |
| D2 | Step bar | 14 px, square, border | Not like the preview | 4 px, radius 2, no border, green #2E8540 (4.1:1) |
| D3 | Bar labels | Two 2-line labels ("Overall: step n of m, x % done, about ...") | 2 x 2 lines of text for 2 bars | P1: 1 line per bar, split left/right. P2: 1 line over both bars; the step detail goes in the running row |
| D4 | "Writes to" | 9.5 pt gray + 10 pt bold path in a FlowLayout | Two sizes on one line; baselines differ | One 10 pt line, path bold |
| D5 | Result buttons | Draft, Copy, Open: 110 x 32, disabled until done | 3 gray buttons with no use during the run | Hidden until DONE, then shown in the row of the "Window" check box (row height kept) |
| D6 | Log | Fill row, bordered, Consolas 9 | Can shrink to nothing at 150 % | Min 80 px; below that it hides itself and the link reads "Show log" |

## 2. Pixel budget

Main body = client height - 20 (top) - 14 (bottom) - 46 (nav: 12 gap + 34 buttons). 100 %: 760 - 80 = **680**. 150 % on 1920 x 1080: work area 1032, form 980, client about 924 / 1.5 = 616, body **536**. Width: 800 main area - 48 padding = 752 at both scales.

| Screen | Rows (px) | Total | Spare at 100 % / 150 % |
|---|---|---|---|
| Choose (P1) | head 57 + n x 80 (card 72 + gap 8) | 57 + 80n | n = 2: 463 / 319; no scroll up to n = 7 / 5 |
| Choose (P2) | head 57 + header 26 + n x 56 + about 16 + 23 | 122 + 56n | n = 2: 446 / 302; no scroll up to n = 9 / 7 |
| Check P1 | head 57 + site 40 + columns 384 (24 + 9 x 40) + counts 40 | 521 | 159 / **15** |
| Check P2 | head 57 + site 40 + header 26 + bands 72 (3 x 24) + 14 x 30 + counts 40 | 655 | 25 / **-119 (scrolls 4 rows)** |
| Deploy P1 | head 60 + bars 83 + steps 26 + 44n + log (min 80) + results 40 + check box 46 | 335 + 44n | n = 3: 213 / 69; log hides above n = 7 (100 %) / n = 4 (150 %) |
| Deploy P2 | as P1 with bars 57 | 309 + 44n | n = 3: 239 / 95; log hides above n = 8 / n = 5 |

Right column in Check P1: 24 + 3 x 40 + 16 + 24 + 2 x 48 = 280 < 384. Missing site address (an app with no site checks): -40.

Not covered: 1280 x 800 at 150 % (R09): body about 364, so P1 Check needs a scroll there (its columns panel scrolls; nothing is cut). Rounding at 150 % can add 1 px per text line; each row keeps 5 px or more of slack.

## 3. Verification limits

WinForms does not run in the cloud. Verified here: the budget arithmetic and the contrast ratios (WCAG formula). Not verified: real text widths and heights on the gov device. Proof comes from the next round's "Window: OK" line.
