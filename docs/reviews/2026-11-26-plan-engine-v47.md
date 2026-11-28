# Plan: engine-v47 and 90-161.Z R47

Approved by the Administrator, 2026-11-26, about 19:20 to 19:40 Central (question dialogs in this RADE session; rows in [../DECISIONS.md](../DECISIONS.md) of 2026-11-26). Mock: https://claude.ai/artifact/E5nJEJfGrnnxaeMpa3K8V9 (option A chosen).

## engine-v47 (this repo)

1. Sign-in: no DPI-aware sign-in. `Set-SignInDpiAware` is off unless `RADE_SIGNIN_DPI=1`; the window sets `RADE_SIGNIN_DPI=0` for its children, so an app's older copy of the block is off too.
2. Branding: the app logo is the taskbar and title-bar icon (own taskbar identity for each app); title "<word> - <version or round>"; the app row from the first screen for a one-product paste; the RADE row's line "Redacted Application Deployment Engine".
3. Choose: "What version of <word> do you want to install?" when every choice has the same product; each choice "<word> <version or round>"; the summary wraps (no cut at full or half width).
4. Maintenance, option A: one card, "<word> <version> is installed.", one list (Repair or Update, Diagnose, Back up, Restore, Uninstall last in dark red), "Start <word>" as the primary button, Back. No second "Maintenance" screen.
5. Out: Remove RADE and the Uninstall clean-up (engine-v48, the Administrator's answer).
6. Release engine-v47; report the tag and commit to 90-161.Z.

## 90-161.Z R47 (the app repo, a session of the app)

1. Lock engine-v47; the copied sign-in block with no DPI call.
2. Fewer sign-ins: join the site steps (about 18 sign-ins to about 6). One sign-in host: later, after R47.
3. The 0-row waves test (done: kanon commit 1ea1220).
4. Record the R46 results first (the round skill), when the Administrator says the e-mail is sent.

## Proof

Cloud: `scripts/check.sh`, the engine tests, the Windows job pictures. Not proven until a work-computer round: the sign-in time without DPI, the taskbar icon, the cut text at half width.
