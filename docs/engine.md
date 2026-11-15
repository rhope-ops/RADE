# RADE engine requirements

Status: decided by the Administrator, 2026-11-14 (docs/DECISIONS.md); not all built. The engine is [../engine/rade_build.py](../engine/rade_build.py) (moved from rhope-ops/90-161.Z on 2026-11-14; apps pin it by sha256). Drift check: [drift-check.md](drift-check.md). Input contract: [../schemas/rade-manifest.schema.json](../schemas/rade-manifest.schema.json).

## Modes

One engine, three modes per catalog app (`mode` in the manifest): **deploy** (install an app), **test** (a test round; the default) and **drift** (owner only). Test rounds are run by the owner only; other users only deploy (the Administrator, 2026-11-14).

## Check stages

1. **Base checks** when the window opens, before Choose: can RADE work on this computer at all (today: `BASE_CHECKS` in rhope-ops/90-161.Z scripts/build_paste_bundles.py). An app whose checks cannot pass is marked on the Choose screen.
2. **App checks** after an app is chosen: each step's `needs` (for example site-rights, flow-guide, pnp).
3. **Drift**: every run compares the check values with the saved baseline; the drift check app forces every check.

## Results

- PASSED, PASSED (fallback), WARNING, FAILED, NOT RUN. A fallback result names the documented fallback route used (for wings with less access) and counts as passed. FAILED or NOT RUN blocks a deploy (rhope-ops/90-161.Z docs/DECISIONS.md, 2026-11-14: "No deploy unless every check passes").
- Saved checks (RADE\Config\rade-checks.json): fast checks (versions, language mode, disk, write, child) run fresh every time; only slow checks (site rights by CAC sign-in, the Power Automate look-and-answer) keep the 7-day reuse; "Run checks again" and the drift check run everything.

## Step contract

What RADE and a step script give each other (the Administrator, 2026-11-14: the contract comes before the safe second run and the undo list). A script that does not use the contract still runs.

**RADE gives the step** (the child process):

| How | Name | Value |
|---|---|---|
| Parameter | `-Id`, `-NoPause` | The profile folder name; no pause at the end. Plus the step's fixed `args` and its `ask` folder. |
| Environment | `RADE_CONTRACT` | `1` (the contract version). |
| Environment | `RADE_MODE` | `test`, `deploy` or `drift`. |
| Environment | `RADE_APP`, `RADE_APP_VERSION` | The chosen app and the version this bundle installs (empty in a test). |
| Environment | `RADE_INSTALLED_VERSION` | The version now installed, or empty (deploy only). |
| Environment | `RADE_STEP_LAST` | This step's last state at this version: `PASSED`, `NEEDS REVIEW`, `SKIPPED` or empty (deploy only). |
| Environment | `RADE_SITE` | The site address from the Check screen, or empty. A step that has it must not ask for it again. |

**The step gives RADE** (one line each on standard output):

| Line | Meaning |
|---|---|
| `PASS ...`, `FAIL ...`, `SKIP ...` | One result each; the step state comes from the counts and the exit code. |
| `PROGRESS n/m` | Moves the step bar; not logged. |
| `MADE <kind>: <name>` | Something the step created (kind: a lowercase word such as `list`, `column`, `flow`, `file`). RADE removes any address from the name and keeps it for the undo list. The line is not a result: words in the name never count as PASS or FAIL. |

A step the user does by hand (kind `guide`) lists what it creates in the manifest field `makes`.

**Rules for a step script:** safe to run again (create only what is missing, and print `MADE` only for what this run created); when `RADE_STEP_LAST` is `PASSED`, check and do nothing if nothing changed; never print a site address, a person or an ID.

In a deploy, RADE saves each step's state, version, time and `made` list under `steps` in RADE\Config\rade-installed.json; a `made` list adds up over runs.

## Deploy v1

Scope approved by the Administrator, 2026-11-14 (docs/DECISIONS.md). RADE is the framework: it runs the checks an app needs, then installs as much as it can before it asks the user for help. A user gets an app from the app's page (github.io); after that, nothing goes back to the owner or the repo.

| # | Item | State |
|---|---|---|
| 1 | Mode branch: a deploy sends nothing. No results e-mail draft, no saved address, no Outlook check, no automatic clipboard copy (the "Copy summary" button stays, for a help request); the report stays in Rounds\<round> on the computer. | Built (text mode tested: tests/engine_test.sh); the window part is not verified on a device |
| 2 | Version record: RADE\Config\rade-installed.json (schema `rade-installed/1`). Per app (folder/name): `installed` = the last deploy in which every step of the app ran and PASSED (none off, none skipped; clean-up may be off, it only recycles old files); `lastRun` = the last deploy run and its state. It holds no user, path, site or DODID. A damaged file is kept as `.damaged` and replaced. The app version is `version` on the manifest app entry (required for a deploy). | Built (same test) |
| 3 | Safe second run: a repeat or an upgrade changes only what is different. The engine gives each step the installed version and its last state ("Step contract"); each step script must be safe to run again. A step that PASSED at this version starts off, and still counts toward "installed"; when every step has PASSED, a run is a repair and every step starts on. A step runs only when each step in its `after` list PASSED; else RADE skips it. Automatic first: the build fails when, in a deploy, a script step comes after a hand step it does not need (`after`), so the app author puts every automatic step before the first hand step. RADE does not reorder steps at run time: only the author knows which step needs which. | Built (text mode tested); the window part (boxes off, "Already done" note) is not verified on a device |
| 4 | Undo list: what a deploy made (files, lists, flows), so a user can remove it. The record keeps each step's `made` list ("Step contract"). Still to build: the screen that shows it. | Record built; the screen not built |
| 5 | A fixed release: a deploy bundle at a tagged, stable address with its sha256 on the app page (a round bundle on main is replaced each round). The paste carries the engine and the scripts; large data files (flow zips, templates) download from the tagged release and are checked by sha256, because a full app does not fit in one paste (the Administrator, 2026-11-14). | Not built (today `fetch` reads from main) |
| 6 | The app page: what the app does, what RADE reads and writes, one Copy button, and how to get help (the Teams channel, by name only; DECISIONS 2026-11-14). | Page not built. The engine names the channel after a deploy that needs review or stops (placeholder name RHOPE-OPS) |

Not in v1: environment values in the manifest (the OneDrive folder name and the site prefix stay in the engine: NIPR is the same everywhere, the Administrator, 2026-11-14). Rights are not the same for every user, so each step that needs extra rights keeps a documented fallback.

After the owner's test rounds end, the test branch and its results e-mail (draft, address box, "window displayed correctly" box) are removed from the engine in one change (the Administrator, 2026-11-14).
