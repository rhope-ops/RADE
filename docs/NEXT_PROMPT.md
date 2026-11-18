# Next prompt: RADE

Updated: 2026-11-18 by Claude (kit port "one check", kit 2026.11.18; engine-v16 = b15c624 released 18 Nov 26). Keep this file short, one line per item, 40 lines or fewer: it counts toward the session load cap. The current request overrides it. Full text of each item: [docs/reviews/2026-11-18-handoff-detail.md](reviews/2026-11-18-handoff-detail.md).

## State

- Engine: latest release engine-v16; the next release raises ENGINE_RELEASE to 17 first (docs/engine.md "Releases"). Tests: `ENGINE pass=114 fail=0`. Nothing after R20 is verified on a device.
- Code standard: docs/code-standard.md; settings in `.check`, debt in `.check.state.json`. Fix debt in files you touch.
- Kit: ported to 2026.11.18 (fbab6b1); RADE's own versions of kit files are the overrides in `.check.lock`. Next port starts there (`port` skill).
- RADE page: https://rhope-ops.github.io/RADE/ (NOT verified on a work computer).

## Open (in order; same numbers in the detail file)

0. Deploy v1: 90-161.Z lock bump and manifest fields, app page, first tagged release.
1. Standards plan: merged; the next engine release takes the catch reasons and strict-mode faults.
2. Engine: size in the summary, version and sha256 in the window, JSON results block.
3. Run-time logo: spec approved 17 Nov 26; build in one engine release.
4. Build docs/engine.md and the drift check.
5-12. Device rounds and proofs, ISSM field list, maintenance run types.
13-16. Review leftovers (MINOR, R28, runner polish, R28 fixes).

## Needs the Administrator

- The final Teams channel name (placeholder RHOPE-OPS in the engine and in apps.json `help`).
- Branch settings: the required pull-request check is now named `checks` (it was `scan`).

## Do not

- None yet.
