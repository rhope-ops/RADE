# Plan: intro screens, Fulcrum palette, shortcut icon (2026-11-21)

Status: decisions approved by the Administrator, 2026-11-21 (question dialog; [DECISIONS.md](../DECISIONS.md)). The build starts after the Administrator approves the preview (step 2). Target: engine-v34, then the work-computer round R42 of rhope-ops/90-161.Z (after R41, which tests engine-v33). Scope: the RADE engine, the manifest schema, docs and tests. Data: fake only.

## Goal

A first-time user sees what RADE is and what the app is before anything is installed. The window uses the Fulcrum palette. Each installed app gets its own shortcut with the app's name and icon.

## Flow

1. **RADE splash.** Black screen. The RADE logo, large and centered; under it the name and the tagline. Button: "Next". The logo fades in from black.
2. **About RADE.** 3 numbered lines: what RADE is, how it works, what it will do on this computer. Button: "Next". Fade out to black.
3. **App splash.** The app's logo, large and centered; its name and summary under it. Button: "Next". Fade in from black.
4. **About the app.** 3 numbered lines that the app supplies: what the app is, how it works, what it can do. The last button:
   - The app has optional steps (`"default": false`): "Next", then the options card.
   - Else: "Install <version>". Agent choice: a button that starts writes says what it does, so the last button is "Install", not "Next".
5. **Options card** (only when the app has optional steps): one check box per optional step, then "Install <version>". Two app versions cannot be in one paste (each version is a new bundle), so this card has no version choice. Two entries of the manifest `apps` list (for example a test round and a deploy) stay on the existing Choose screen.

Shown: one time for a Windows profile, and again from "Help (F1)". Cards 1-2 replace the 5-card tour (R31 L6). Cards 3-4 show one time for each app on that profile. Back (Esc) goes one card back.

## Steps

1. **Large logos.** The logos are PNGs of 128 px today (RADE: `rho-fulcrum-128.png`; apps: `application.logo`, "128 px is enough"). At 150 % a centered logo of about 240 px would be blurry. Build the run-time logo first ([specs/run-time-logo.md](../specs/run-time-logo.md), approved 2026-11-17): the logo is drawn from the SVG at any size. An app then gives an SVG logo.
2. **Preview.** Pictures of cards 1-5 and two working cards in the Fulcrum palette, at 100 % and 150 %, and in a contrast theme; a short frame strip of one fade. Lane C: the Administrator approves the preview before the build.
3. **Fulcrum tokens.** engine/ui-tokens.json takes the Fulcrum colors for every role, and the contrast test (text 4.5:1, non-text 3:1) must pass. Measured on 2026-11-21: near-black #15171D on orange #E4572E 4.86:1 (pass); white on orange 3.68:1 and cream #F3EEE4 on orange 3.19:1 (fail for text); cream on near-black 15.49:1; gray #5A5E6A on cream 5.60:1; gray on near-black 2.77:1 (fail). So: the primary button is orange with near-black text; links are near-black and underlined (orange text fails on cream); muted text on the black intro cards uses cream, not gray. The RADE page (index.html) takes the same tokens through scripts/ui_tokens.py.
4. **Intro cards.** New views in the window (engine/ps/window), built with the existing card builders (`$ui.SetCard`); they replace `$ui.TourCards` and `$ui.VTour`. RADE's own lines are RADE text; the app's lines come from the manifest.
5. **Manifest field.** `application.intro`: 3 lines (what, how, does), each at most 150 characters. Optional: without it, card 4 shows the app summary. Schema, docs/make-an-app.md, the app canary (scripts/check_apps.py).
6. **Fades.** A timer paints the card with a black layer that goes from 100 % to 0 % (fade in) or back (fade out) in about 300 ms. No fade, a plain cut, when Windows animations are off (`SystemInformation.UIEffectsEnabled`), in a contrast theme, or in a remote session (`SystemInformation.TerminalServerSession`). This keeps the rule "still when Windows animations are off" (window-design.md).
7. **App shortcut.** RADE is never installed by itself, so the shortcut belongs to the app (the Administrator, 2026-11-21). At a deploy RADE makes one shortcut for each installed app: its name is the app's name, its icon is `<key>.ico` (16, 32, 48 and 256 px, made from `application.logo`; the RADE logo when the app has none), and it opens that app's own runner copy (`RADE\runners\<key>.ps1`, the app's last passed paste; `<key>` = the 12-hex name of the app's install record). So a deploy of a second app does not change the first app's shortcut. Today's one shortcut "RADE" and one runner (`rade-runner.ps1`, engine.md "Shared files") go: the next deploy moves the old `RADE.lnk` to the Recycle Bin, as a made item of RADE. Code: engine/ps/05-installed.ps1 `Add-DesktopIcon` (`IconLocation`).
8. **Tests and self-check.** The layout self-check covers cards 1-5 (centered logo, the text column, no cut text). The Windows job draws each card, once with fades off. A unit test checks the .ico file (sizes, header).
9. **Release** engine-v34 and send the tag to 90-161.Z. That app adds `application.intro` and an SVG logo, then R42.

## R42 test items (work computer, Windows PowerShell 5.1)

- T1 The splash and About cards show on a fresh profile, and not again on the next run; Help (F1) shows them again.
- T2 The fades are smooth, or a plain cut when animations are off; no flicker at 150 %.
- T3 The logos are sharp at the work computer's scale.
- T4 The Fulcrum colors read well; the contrast theme shows system colors.
- T5 The options card shows only for an app with optional steps; "Install" starts the deploy.
- T6 The shortcut has the app's name and icon, also after a sign-out and sign-in; it opens RADE for that app; the old RADE shortcut is in the Recycle Bin.

## Assumptions (source, confidence)

- A1 R42 is the next round after R41 (docs/NEXT_PROMPT.md; medium). If R41 slips, this goes to the round after the one that tests engine-v33.
- A2 The run-time logo can be built in this release; if not, a 512 px PNG travels in the bundle as a stopgap, about 30-60 KB bigger (medium).
- A3 Windows shows an icon from a file in the RADE folder; with two apps, each shortcut keeps its own icon and runner (agent design; medium). The RADE folder is under OneDrive: a file that OneDrive keeps online only can show a blank icon. If T6 fails, the .ico goes to the user's local app data folder (low; T6 is the proof).
- A4 A timer fade of about 300 ms runs smoothly on Windows PowerShell 5.1 with Windows Forms (medium; T2 is the proof).

## Gaps

- **Reduced motion:** covered by step 6. Without it, the fades would be a WCAG 2.3.3 risk.
- **Time to install:** 4-5 cards before the first write. One time per profile and app keeps the cost low.
- **Screen readers:** each intro card needs an AccessibleName on the logo and the lines (ui-standard.md, existing rule).
- **Icon proof:** only a work computer proves T6; the cloud Windows job has no OneDrive.
</content>
</invoke>
