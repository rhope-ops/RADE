# Plan: UI standard v1 (2026-11-20)

Approved: the Administrator , 2026-11-20, through the brief of the 90-161.Z session ("Start a separate RADE session now to build UI standard v1"). Scope: RADE engine, docs and tests; one RADE pull request; engine-v28 when green and reviewed. Data: fake only.

## Steps (brief items)

1. Contrast themes (backlog item 24): `$ui.Color`, `$ui.UseColors`, `$ui.Recolor` in engine/rade_ui.ps1; role map from the brief.
2. Buttons: fixed sizes (action 160x40, wide 240x40, compact 96x30, link = text x 28), primary last, one primary, at most 4 buttons, one Back pattern (compact "Back (Esc)" at the left), action row in view.
3. Spacing 4/8/12/16/24, side inset 24, field widths S 240 / M 420 / L 600.
4. Fonts: Sofia Sans (text), Sofia Sans Condensed (titles), engine/fonts/ with OFL.txt, PrivateFontCollection plus the GDI memory font, Segoe UI fallback; index.html the same.
5. Feedback on every card: comment and a PNG of the window into the round's results folder (extends the feedback card).
6. engine/ui-tokens.json: the one home of colors, sizes, gaps, type and field widths; contrast test (text 4.5:1, non-text 3:1); the build writes `$ui.C` and `$ui.Z`; index.html CSS from it.
7. `$ui.Check` rules and `-Inventory` mode; tests/window_real.py at 100/125/150/200 % and once with a contrast theme.
8. docs/ui-standard.md (rules B1-B13 with their checks); docs/window-design.md trimmed and linked; docs/make-an-app.md "Adopt the UI standard"; apps.json `"ui": "v1"`.
9. `rade_hash.py --content` with a unit test.

## Assumptions (source, confidence)

- A1 Fonts are a Latin subset (U+0020-007E, U+00A0-017F, punctuation, arrows), with no OpenType layout tables GDI does not use: about 43 KB each, so a bundle grows by about 170 KB, not 770 KB (measured, scratch build; high). A character outside the subset can show as a box: the build checks the app's texts (medium).
- A2 The Feedback link shows in test rounds only: a deploy sends nothing and keeps one record file (docs/engine.md "Deploy v1"; medium).
- A3 Cards over the 4-button cap lose the "not available" placeholder buttons first (Maintenance: Diagnose, Back up, Restore) (agent choice; medium; preview in the PR).
- A4 The Windows job simulates 125 % and 200 % as it does 150 % (auto-scale swap) and a contrast theme by a swap that turns `HighContrast` on; the real theme on a work computer is the last proof (high).
- A5 .github/workflows/window.yml needs no change: tests/window_real.py runs the new runs and writes the inventory into window-out, which the job uploads (high).
</content>
</invoke>
