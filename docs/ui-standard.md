# UI standard v1

Status: decided by the Administrator, 2026-11-20 (as PFM, through the brief of the 90-161.Z session; [plan](reviews/2026-11-20-plan-ui-standard-v1.md)). The one home of the rules every window follows: the RADE window, 90-161.Z and the next apps (ICF, SEC). The values live in [engine/ui-tokens.json](../engine/ui-tokens.json); the engine reads them through the token block of [engine/rade_ui.ps1](../engine/rade_ui.ps1) (written by `python3 engine/rade_tokens.py --write`; a build stops when the block is old). RADE-window specifics stay in [window-design.md](window-design.md). How an app adopts it: [make-an-app.md](make-an-app.md) "Adopt the UI standard".

## Rules

Sizes are pixels at 100 % Windows scaling; every size set after the window has its scale goes through `$ui.Sc`. "Self-check" is `$ui.Check` (engine/rade_ui.ps1): in a test round and in the Windows job it reports each defect as a `LAYOUT` line.

| No. | Rule | Check |
|---|---|---|
| B1 | Buttons have fixed sizes, never AutoSize: action 160 x 40; wide 240 x 40 only for a label that does not fit 160; compact 96 x 30 (beside a box, "Back (Esc)", the Record's buttons), 160 x 30 for a compact label that does not fit 96; a link is as wide as its text and 28 high. A label must fit its button. A one-line box is as tall as the compact button (R36: at 150 % an unscaled frame cut the box's line). | Self-check `$ui.BtnBad` and the box-height line; stand-in test `WIN BAD button` (tests/window_driver.ps1) |
| B2 | Gaps are 4, 8, 12, 16 or 24 only; one side inset, 24. A button or link keeps a 4 px margin for the focus ring. | engine/rade_tokens.py stops a build with other gaps; review |
| B3 | The primary button is the last one, alone at the right end of the action row; Enter selects it. | Self-check `$ui.RowRuleBad`; `$ui.SetCard` orders the row |
| B4 | At most one primary button on a card. A card that waits for a choice of the person has one; a question whose buttons are its answers and the Run card's Cancel have none. | Self-check `$ui.RowRuleBad` |
| B5 | At most the primary and 3 other buttons ("Back (Esc)" is not counted). | Self-check `$ui.RowRuleBad`; stand-in test `WIN BAD buttons` |
| B6 | One Back pattern: a compact "Back (Esc)" at the left end of the action row; Esc does the same. | Stand-in tests (`back=True`); the edge rule measures it as the row's first part |
| B7 | "Record (F2)", "Help (F1)" and "Feedback" are links in the bottom line, never buttons. | Stand-in tests (no "Record" button) |
| B8 | The action row stays in view; only the card body above it scrolls. | `$ui.Squeeze`; tests/window_real.py (scroll rule per window size) |
| B9 | Field widths: S 240, M 420, L 600 (a box never wider than the card). | Tokens `FieldS`, `FieldM`, `FieldL`; review |
| B10 | Each color has one role. Text is at least 4.5:1 on its background (WCAG 2.2 SC 1.4.3), a non-text part at least 3:1 (SC 1.4.11). | scripts/ui_tokens.py on every pair of the tokens; self-check contrast line for each text control as drawn |
| B11 | Windows contrast themes: each color token has a SystemColors role (surface Window, text WindowText, muted GrayText, primary fill Highlight with HighlightText text, button ButtonFace with ControlText (the button text of the theme), focus and links HotTrack). With a contrast theme on, the window paints with those colors, and it follows a theme that changes while it is open (`$ui.Recolor` on the form's SystemColorsChanged). The RADE page has the same roles in its `forced-colors` block, and a `prefers-contrast` block. | tests/window_real.py run `contrast-full`; scripts/ui_tokens.py writes and checks the page's blocks |
| B12 | Type: Sofia Sans Condensed for titles (the headline, the word RADE), Sofia Sans for text, Consolas for the Record's text box only; Segoe UI when a font cannot be loaded. The fonts load for the process only (PrivateFontCollection and a GDI memory font: no install, no administrator). Styles and sizes: the tokens. The RADE page uses the same families with Segoe UI after them. | The SCALE facts (`WIN high=... fonts=...`); stand-in tests (one font per style) |
| B13 | Feedback: in a test round, every card has the link "Feedback" at the same place (the bottom line). It opens a comment card; Save writes the comment (masked as a text answer is) and a PNG of the window into `Rounds\<round>\Feedback`. That folder is not attached to the results e-mail: the picture shows the real profile path (AGENTS.md "Project rules", DoD365 boundary). | Stand-in test `WIN note` (tests/engine_window.sh, window 3) |

## Fonts (B12)

engine/fonts holds the three files: a Latin subset of the Sofia Sans release files, SIL Open Font License 1.1 (engine/fonts/OFL.txt), about 43 KB each, so a bundle grows by about 170 KB. [scripts/build_fonts.py](../scripts/build_fonts.py) makes them again from the release files, checked by SHA-256. They are binary, so the content check skips them (`.check`: `skip: engine/fonts/*.ttf`, the Administrator, 2026-11-20). A character outside the subset (Basic Latin, Latin-1, Latin Extended-A, common punctuation, arrows) can show as a box.

## Proof

| What | Where |
|---|---|
| Contrast of every pair, and the page's colors | `python3 scripts/ui_tokens.py` (scripts/check.local.sh) |
| The token block is current | every build (engine/rade_tokens.py `check_tokens`) |
| B1, B3 to B5, B10 on each card the window shows | the self-check, in a test round and in the Windows job |
| 100, 125, 150 and 200 %, and a contrast theme | tests/window_real.py: the runs `deploy-*`, `test-small`, `long-*` (100 %), `device125-full`, `device150-half`, `device200-full`, `contrast-full` (a test copy turns `$ui.HighOn` on; the job's own theme stays) |
| Inventory | `RADE_INVENTORY` = a file: one JSON line per control of each card (card, scale, kind, name, screen box, colors, accessible name, button kind); the Windows job keeps `inventory.jsonl` of each run with its pictures |
| Not proven in the cloud | a real Windows contrast theme and real 125 % or 200 % scaling on a work computer: a test round is the last proof |
