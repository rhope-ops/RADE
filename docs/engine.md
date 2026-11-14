# RADE engine requirements

Status: decided by the Administrator, 2026-11-14 (docs/DECISIONS.md); not all built. The engine still lives in rhope-ops/90-161.Z scripts/build_paste_bundles.py until R17 confirms the window. Drift check: [drift-check.md](drift-check.md). Input contract: [../schemas/rade-manifest.schema.json](../schemas/rade-manifest.schema.json).

## Modes

One engine, three modes per catalog app (`mode` in the manifest): **deploy** (install an app), **test** (a test round; the default) and **drift** (owner only). Test mode is permanent: RADE keeps running test rounds as the local NIPR environment changes.

## Check stages

1. **Base checks** when the window opens, before Choose: can RADE work on this computer at all (today: `BASE_CHECKS` in rhope-ops/90-161.Z scripts/build_paste_bundles.py). An app whose checks cannot pass is marked on the Choose screen.
2. **App checks** after an app is chosen: each step's `needs` (for example site-rights, flow-guide, pnp).
3. **Drift**: every run compares the check values with the saved baseline; the drift check app forces every check.

## Results

- PASSED, PASSED (fallback), WARNING, FAILED, NOT RUN. A fallback result names the documented fallback route used (for wings with less access) and counts as passed. FAILED or NOT RUN blocks a deploy (rhope-ops/90-161.Z docs/DECISIONS.md, 2026-11-14: "No deploy unless every check passes").
- Saved checks (RADE\Config\rade-checks.json): fast checks (versions, language mode, disk, write, child) run fresh every time; only slow checks (site rights by CAC sign-in, the Power Automate look-and-answer) keep the 7-day reuse; "Run checks again" and the drift check run everything.
