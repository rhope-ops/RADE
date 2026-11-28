# Spec: run-time logo

Status: Approved 2026-11-17 · Administrator: the Administrator · Updated: 2026-11-17

## Goal
RADE and every app draw their logo with code at run time on the work computer, so no PNG file is kept in a repo or sent in a bundle. A reviewer can read the logo as text, and bundles get smaller (90-161.Z R29a: about 72 KB of base64 PNG out of 585 KB).

## Done
Both logos (RADE Rho Bold, 90-161.Z W2) show in the window and as the SharePoint site logo, drawn by the engine from a shape list, and no `.png` file or base64 PNG remains in either repo or in any bundle.

## Requirements
- R1. One engine function (PowerShell, in `engine/ps/`) draws a logo from a shape list into a `System.Drawing.Bitmap` of any size. Windows PowerShell 5.1, `System.Drawing` only (no other module).
- R2. The shape list supports every SVG feature the two logos use: `circle`, `rect`, `line`, `path` (commands M L H V C S Q T A Z, absolute and relative), `g` and element `transform` (translate, scale, skewX), `clipPath` of rectangles, fill, stroke, `stroke-width`, `stroke-dasharray`, round line caps and joins.
- R3. The SVG stays the master (`assets/logo/*.svg`). A build step turns it into the shape list (plain text in the bundle, not base64). It reuses the SVG reader of rhope-ops/90-161.Z `scripts/logo_draw.py` (`shapes()`, `path_segments()`, `arc_segment()`), moved to RADE so both apps use one copy (code standard C5).
- R4. The build refuses any SVG element, attribute or path command it cannot convert, with the element named (as `logo_draw.py` does now).
- R5. The window shows the logo from the run-time drawing (RADE: top left; 90-161.Z: the app-logo block of its window).
- R6. An app that needs a logo file (SharePoint site logo and thumbnail) gets a PNG written by R1 to the user's temp folder at run time, at the size the step names; the step says the path to the user.
- R7. Removed in the same change that ships R1–R6: RADE `assets/logo/logo-rho-*.png`, `scripts/render_logo.js` and the PNG entries in the engine file list and the app lock; 90-161.Z `scripts/logo_png.py`, `assets/logo/90161Z-logo.render.json`, the base64 `$AppLogoPng` block and the PNG part of `scripts/logo_draw.py` (the SVG reader moves to RADE, R3).
- R8. Every new file and function meets the code standard (docs/code-standard.md, with C2 full and C1 safety).

## Out of scope
- A new logo design or a color change.
- Logos of apps other than RADE and 90-161.Z.
- Drawing anything other than the logo in code.

## Edge cases and errors
- E1. `System.Drawing` cannot load (a stripped computer) -> the window shows the app name as text in place of the logo and goes on; a site-logo step stops with a plain message and no upload.
- E2. The temp folder cannot be written -> the site-logo step stops with a plain message; no other step changes.
- E3. A new SVG uses a feature R2 does not list -> the build fails and names the element (R4); no bundle is made.
- E4. A very small size (16 px) -> the drawing still fills the disc; no crash.

## Constraints
- Windows PowerShell 5.1 and .NET Framework `System.Drawing` (GDI+) on every NIPR computer; PowerShell 7 on Linux cannot use GDI+, so the drawing is proved on Windows only (the GitHub `windows-latest` runner and a work-computer round).
- No network access, no file outside the temp folder (R6), no credentials.
- Bundle size: the shape list and the drawing function must be smaller than the base64 PNGs they replace.

## Decisions
| ID | Decision | By | Date | Alternatives rejected, and why |
|---|---|---|---|---|
| D1 | Draw the logo at run time; no PNG in the repo or the bundle. | the Administrator | 2026-11-17 | SVG master with a PNG built and embedded (PNG bytes still travel); keep the PNG renderer |
| D2 | The PNG renderer in 90-161.Z (logo_draw.py) stays until this ships; this reuses its SVG reader. | the Administrator | 2026-11-17 | Stop it at once (R29 would need a rebuild) |
| D3 | Proof on the GitHub Windows runner and a work-computer look check. | the Administrator | 2026-11-17 | Work computer only (slow, by eye only) |
| D5 | If the Windows runner cannot render the reference images, they live in `tests/` as test data only, never in a bundle or a release. | the Administrator | 2026-11-18 | The test draws its own reference only (blocks A2 if the runner cannot) |
| D4 | A2 tolerance: at least 98 % of pixels within 8/255 per channel at 512 and 128 px. | the Administrator | 2026-11-17 | Equal pixels (GDI+ and Chromium anti-aliasing differ) |

## Acceptance checks
| ID | Covers | Check | Pass when |
|---|---|---|---|
| A1 | R7 | `git ls-files '*.png'` in both repos, and `grep -c iVBORw0KGgo` on every tracked file and every bundle | no PNG file; count 0 |
| A2 | R1, R2, R5, E4 | A new step in `.github/workflows/window.yml` (Windows PowerShell 5.1) draws each logo at 512, 128 and 16 px and compares each with a reference render of the SVG (Chromium, in the same job) | at least 98 % of pixels within 8/255 per channel at 512 and 128 px (the Administrator, 2026-11-17); 16 px draws without error |
| A3 | R3, R4, E3 | Build test: each logo SVG converts; a sample SVG with an `<ellipse>` and one with a `B` path command fail with the element named | both pass and fail as stated |
| A4 | R6, E2 | Windows job: the site-logo step writes a 512 px PNG to a temp folder; with a read-only temp folder it stops with its message | file exists and opens as a 512 x 512 image; message shown, exit without upload |
| A5 | E1 | Windows job: run the window with `System.Drawing` load forced to fail | the app name shows as text; no crash |
| A6 | R5, R6 | Work-computer round card: the Administrator looks at the window logo and the site logo | the Administrator answers "looks right" |
| A7 | R8 | `python3 scripts/code_standard.py` in both repos | `CODE-STANDARD pass` with no new debt |
| A8 | Goal (size) | Bundle size of the next 90-161.Z round before and after | the new bundle is smaller |

## Assumptions
- `System.Drawing` (GDI+) is present on every NIPR computer with Windows PowerShell 5.1 · it ships with .NET Framework · high.
- GDI+ anti-aliasing differs a little from Chromium, so A2 needs a tolerance, not equal pixels · medium.
- The GitHub Windows runner can run Chromium (Playwright) for the reference render · medium; else reference PNGs live in `tests/` as test data only, never in a bundle (D5).

## Risks
- The Rho Bold glyph path has about 200 curve commands; a converter bug shows as a wrong shape. REC: A2 at 512 px catches it; build the converter test-first from both SVGs.
- The bundle grows if the drawing function is large. REC: A8; keep the shape list compact (numbers rounded to 0.1).
