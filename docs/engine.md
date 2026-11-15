# RADE engine requirements

Status: decided by the Administrator, 2026-11-14 (docs/DECISIONS.md); not all built. The engine is [../engine/rade_build.py](../engine/rade_build.py) (moved from rhope-ops/90-161.Z on 2026-11-14; apps fetch it by commit: "How an app gets the engine"). Drift check: [drift-check.md](drift-check.md). Input contract: [../schemas/rade-manifest.schema.json](../schemas/rade-manifest.schema.json).

## RADE and the app

Decided by the Administrator, 2026-11-14. RADE owns the computer and the run. The app owns the product and the site. RADE may know a platform (SharePoint, Power Automate, Word, Outlook), never an app's objects (a list, column, flow or setting by name). Test for any line of code or text: would it be the same for a different app? If yes, it is RADE's.

| Subject | RADE | The selected app |
|---|---|---|
| Window, screens, bars, log, report | Owns all of it | Supplies its name, summary, step notes and help text |
| Checks | Runs them; owns the check library | Declares which checks each step needs (`needs`) |
| Files on the computer | Makes folders, writes and downloads files, verifies sha256, recycles old files | Declares the files and the clean-up patterns |
| Order and gating | Runs steps in manifest order, applies `after`, blocks on a failed check | The author sets the order and the dependencies |
| What is created on the site or in Power Automate | Creates nothing of its own there | Declares or scripts every list, column, permission, flow and setting |
| Steps done by hand | Opens the address, shows the numbered steps, waits for Done or It failed | Writes the guide text; owns what the user imports |
| Values asked from the user | Asks what the install needs (site address), passes it once (`RADE_SITE`) | Asks its own settings in its own setup screen |
| Record of the install | Keeps the version, each step's state and the made list | Prints `PASS`, `FAIL` and `MADE` lines; each script is safe to run again |
| App data (rows, files, backups) | May read and write it inside DoD365 where a run type needs it (Diagnose, Restore, backup); how is not decided | Owns it; declares what RADE may touch |
| After the install | Not present; the app works if RADE is deleted | Flows, the Power App, health and its own alerts |
| Help | Names the Teams channel | Says what to do when one of its steps needs review |

Hard rule (the Administrator, 2026-11-14): users cannot write data across the DoD365 boundary through any of the Administrator's apps, RADE included. Inside DoD365 (the site, the user's OneDrive) RADE may read and write. The first version of the two rows above said RADE never writes to the site or touches app data; that was agent wording and is replaced.

No reconnaissance (the Administrator, 2026-11-14; cannot be changed): RADE, every app, every step, flow and test, and every agent that writes them, must never do anything that is malicious in nature or that could be misconstrued as malicious. Never, with no exception: finding or pinging hosts on the network, port checks, or working out network or logical boundaries by probing. Allowed: reading SharePoint and Power Platform data with the user's own account, in the open (the script says what it reads before it runs), including to record what that account can do so an app can be deployed. If there is any doubt, stop and seek approval from the owner before the code is written or run.

Environment (the Administrator, 2026-11-14): what works on the owner's NIPR computer works on every NIPR computer, PnP.PowerShell included; the owner's account has no special flag. Windows PowerShell 5.1 is the least that is always there: all engine and step code runs on it. The work-computer rounds are the 5.1 test; the cloud tests stay on PowerShell 7, and a 5.1 fault is fixed when a round finds it.

Preflight: RADE's checks are the one preflight; an app keeps a probe flow only for rights a script cannot see (for example the connector data policy, Send As). Updates: RADE compares the installed version with the newest one at each run; an app only shows its installed version.

## How an app gets the engine

The Administrator, 2026-11-15. An app repo builds alone: it needs no RADE checkout.

- The app keeps a lock file that names a RADE commit and every file the engine reads at that commit, each with its SHA-256. Today the engine reads 2 files: `engine/rade_build.py` and `assets/logo/logo-K-128.png`. `python3 scripts/engine_files.py` gives the list from a trace of the engine's file opens on the sample build, not from a search: a new engine can read a new file.
- The app's build downloads those files from `raw.githubusercontent.com/rhope-ops/RADE/<commit>/<path>`, checks each SHA-256, and runs the engine with `--app-root`. A commit never changes, so the same lock always gives the same bundle.
- The app owns its lock. A RADE session never edits an app repo: it reports the new commit, and a session of the app changes the lock, rebuilds and tests. Rollback = the app keeps its old lock.
- Releases: after an engine change merges, a manual run of the workflow [release.yml](../.github/workflows/release.yml) from main (input: the next tag, `engine-v<N>`) runs the checks, signs the file list as a build attestation (keyless, no secret) and makes the tag and the GitHub release with `rade-engine.sha256` (the signed list, the authority) and `rade-engine.lock.json` (the same hashes in lock form). The app copies the commit and the hashes from that release into its lock and records the tag. The app's build still fetches by commit and checks the hashes; it needs no new tool. To check the signature by hand: `gh attestation verify engine/rade_build.py --repo rhope-ops/RADE`.
- What an app repo must hold: [make-an-app.md](make-an-app.md).
- First app and working example: rhope-ops/90-161.Z `scripts/rade.lock.json`, `scripts/build_paste_bundles.py`, docs/dev-setup.md "RADE engine".

## Guardrails

Decided by the Administrator, 2026-11-14. Each one stops an honest mistake; none is a security control.

| Guardrail | What RADE does | What it reads or writes |
|---|---|---|
| NIPR only | Before anything is written, RADE compares the endings of this computer's own domain names with the classified-network suffixes (`$classifiedSuffixes` in the engine). On a match it prints STOPPED and ends: no folder, file, saved check, window or e-mail. The same test is the first check row (`nipr`, never saved). It cannot prove NIPR. | Reads two local values (the logon domain and the computer's domain). Contacts no host. The names are never shown or saved. |
| Site address | Only an address that starts with the DAF SharePoint prefix (`$sitePrefix`) is accepted, so RADE never signs in to or writes to another host. | Nothing new. |
| Site rights | Unchanged: manage lists, manage the site and manage permissions (Full Control). The sign-in check also shows whether the user's own account is a site collection administrator. Shown only, never required. | Reads one flag of the user's own account. No list of administrators. |
| One install per site | An app with `marker` in the manifest (list, row key, column) keeps an install record on the site: after a deploy that reached a step, RADE writes the version and the date to that one row (with the word "partial" until every needed step has passed). In a deploy the sign-in check reads the row; any value counts. A site that has it, and an account whose own record ("Shared files") holds no step for that site: the check is FAILED and no step runs (a second import would run every flow twice). For such an app the record is kept for each site: its key ends in `@` and a short hash of the site address, never the address, so versions, step states and the made list of one site do not count on another. The row is not written when the own record could not be saved. In the window, a changed site address drops the site results shown for the old one. A row that cannot be read is FAILED too. A first install always reads the row fresh, and the plan shows a "once for each wing" notice. If the row cannot be written, the run says so. | Reads and writes one row of the app's own list. No name. |

Limits: RADE cannot see an install on another site (that needs a tenant search, which "No reconnaissance" forbids). Until the Maintenance screen exists, only the account that installed an app can update it; if that account's record file is lost or damaged, its next deploy is stopped too, and a site owner must clear the row's value by hand. A run that stops inside its first step writes no row. A renamed app has a new record key, so its installer is stopped until the row is cleared. Not verified on a device: the window's handling of a changed site address, the suffix list, the administrator read and the row read and write on PnP.PowerShell 1.12.0 (cloud tests use a fake module, tests/fake-pnp).

## Shared files

Decided by the Administrator, 2026-11-15. The RADE page picks the app, and each app is one paste with its own engine lock, so several engine versions use `OneDrive\RADE\Config` on one computer. An engine cannot keep fields it does not know through a read and a write (PowerShell cuts data below its depth limit with no error), so no engine rewrites another app's data.

| File in RADE\Config | Holds | Written by | If it is lost |
|---|---|---|---|
| `installed\<12 hex>.json` | One app's install record: version, step states, the made list. Name = the first 12 hex of the SHA-256 of the lower-case record key. Contract: [../schemas/rade-installed.schema.json](../schemas/rade-installed.schema.json) | Only a deploy of that app | The app reads as not installed; with a site marker its next deploy is stopped ("Guardrails") |
| `rade-checks.json` | Saved checks (a cache). Contract: [../schemas/rade-checks.schema.json](../schemas/rade-checks.schema.json) | Every run of every app | A check runs again |
| `rade-mail-to.txt` | The results address (test rounds) | A test round | The owner types it again |

- S1. An engine writes only its own app's record file.
- S2. A record with a schema number higher than the engine knows is not read and not written, and that app is not deployed: "a newer RADE installed this application: get the newest script from the RADE page".
- S3. `rade-checks.json` is a cache: nothing goes in it whose loss matters.
- S4. A record or cache write goes to a temporary file in the same folder, which then replaces the final file in one step.
- S5. Only a file with the exact name is read: a conflict copy that OneDrive makes is ignored.
- A change to a record that an older engine cannot read gets the next schema number (S2 then stops the older engine).

Engine-v1 (the engine in the field on 2026-11-15) kept all apps in one file, `rade-installed.json`. No deploy ran with it, so the file is not read or moved. tests/engine_test.sh runs engine-v1 and this engine on one folder ("cross-version"). A test round runs a self-test of the record functions on a scratch folder and prints 4 `PASS shared files` lines: that is the proof on Windows PowerShell 5.1. Not verified on a device: all of this section, and the file replace inside a OneDrive folder.

## Modes

One engine, three modes per catalog app (`mode` in the manifest): **deploy** (install an app), **test** (a test round; the default) and **drift** (owner only). Test rounds are run by the owner only; other users only deploy (the Administrator, 2026-11-14).

## Check stages

1. **Base checks** when the window opens, before Choose: can RADE work on this computer at all (`BASE_CHECKS` in the engine). An app whose checks cannot pass is marked on the Choose screen.
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
| `FALLBACK: <route>` | The step used its documented fallback route (for a user with fewer rights). A step that passes this way reads PASSED (fallback) and counts as passed. |
| `MADE <kind>: <name>` | Something the step created (kind: a lowercase word such as `list`, `column`, `flow`, `file`). RADE removes any address from the name and keeps it for the undo list. The line is not a result: words in the name never count as PASS or FAIL. |

A step the user does by hand (kind `guide`) lists what it creates in the manifest field `makes`. A step may give its own help text in the manifest field `help`; RADE shows it when the step needs review.

**Rules for a step script:** safe to run again (create only what is missing, and print `MADE` only for what this run created); when `RADE_STEP_LAST` is `PASSED`, check and do nothing if nothing changed; never print a site address, a person or an ID.

In a deploy, RADE saves each step's state, version, time and `made` list under `steps` in the app's record file ("Shared files"); a `made` list adds up over runs.

## Deploy v1

Scope approved by the Administrator, 2026-11-14 (docs/DECISIONS.md). RADE is the framework: it runs the checks an app needs, then installs as much as it can before it asks the user for help. A user gets an app from the app's page (github.io); after that, nothing goes back to the owner or the repo.

| # | Item | State |
|---|---|---|
| 1 | Mode branch: a deploy sends nothing. No results e-mail draft, no saved address, no Outlook check, no automatic clipboard copy (the "Copy summary" button stays, for a help request); the report stays in Rounds\<round> on the computer. | Built (text mode tested: tests/engine_test.sh); the window part is not verified on a device |
| 2 | Version record: one file for each app in RADE\Config\installed (schema `rade-installed/2`; "Shared files"). Per app (folder/name): `installed` = the last deploy after which every needed step of the app has PASSED at that version (none skipped; a step is optional only when the manifest says `"default": false`; clean-up may be off, it only recycles old files); `lastRun` = the last deploy run and its state. It holds no user, path, site address or DODID (for an app with `marker` the key ends in a short hash of the site address: "Guardrails"). A damaged file is kept as `.damaged` and replaced; a record of a newer RADE stops the deploy. The app version is `version` on the manifest app entry (required for a deploy). | Built (same test) |
| 3 | Safe second run: a repeat or an upgrade changes only what is different. The engine gives each step the installed version and its last state ("Step contract"); each step script must be safe to run again. A step that PASSED at this version starts off, and still counts toward "installed"; when every needed step has PASSED, a run is a repair and every needed step starts on. In a deploy a needed step is on until it has PASSED, whatever a files-changed default says. A step runs only when each step in its `after` list PASSED; else RADE skips it. Automatic first: the build fails when, in a deploy, a script step comes after a hand step it does not need (`after`), so the app author puts every automatic step before the first hand step. RADE does not reorder steps at run time: only the author knows which step needs which. | Built (text mode tested); the window part (boxes off, "Already done" note) is not verified on a device |
| 4 | Undo list: what a deploy made (files, lists, flows), so a user can remove it by hand. The record keeps each step's `made` list ("Step contract"); a deploy prints the list in its log and report. The window shows the counts on Done and the list in the Record. | Built (text mode tested; the window part is not verified on a device) |
| 5 | A fixed release: a deploy bundle at a tagged, stable address with its sha256 on the app page (a round bundle on main is replaced each round). The paste carries the engine and the scripts; large data files (flow zips, templates) download from the tagged release and are checked by sha256, because a full app does not fit in one paste (the Administrator, 2026-11-14). | Built (text mode tested): the bundle field `release` names the tag, and with a failed download a deploy runs no step. Not done: no app has a tagged release yet |
| 6 | The app page: what the app does, what RADE reads and writes, one Copy button, and how to get help (the Teams channel, by name only; DECISIONS 2026-11-14). | App pages not built. The RADE page (index.html, 2026-11-14) has the Copy button, the paste steps and the channel name for every application, not what an app does, reads and writes. The engine names the channel after a deploy that needs review or stops (placeholder name RHOPE-OPS) |

Newer version: in a deploy RADE reads `rade-release.json` at the root of the app repo on main (`{ "apps": { "<app name>": "<version>" } }`, written by the app author at each release) and names a newer version in the log.

**Function complete (2026-11-14):** items 1 to 5 and the step contract are in the engine and tested in text mode. Left: item 6 (the app page, in each app repo) and proof on a device. The window ("One thing", docs/window-design.md) is built and not verified on a device.

Not in v1: environment values in the manifest (the OneDrive folder name and the site prefix stay in the engine: NIPR is the same everywhere, the Administrator, 2026-11-14). Rights are not the same for every user, so each step that needs extra rights keeps a documented fallback.

After the owner's test rounds end, the test branch and its results e-mail (draft, address box, "window displayed correctly" box) are removed from the engine in one change (the Administrator, 2026-11-14).

## Maintenance run types

Decided by the Administrator, 2026-11-14: RADE offers Install, Diagnose, Restore and Uninstall as run types and keeps the record right for each (version, step states, made list); the app supplies what each needs. Not built.

Decided by the Administrator, 2026-11-14: the screen has the title "Maintenance", is shown for an app that is installed, and has five action buttons:

| Button | Does | Writes | Asks first |
|---|---|---|---|
| Install (reads "Update to <version>" or "Repair" by state) | Adds what is missing, updates flows and app, keeps data | Site, Power Automate (hand steps), the record | No |
| Diagnose | Read-only checks; each finding names its fix | A report on the computer | No |
| Back up | Saves every app list as JSON plus a CSV copy | The backup folder | No |
| Restore | Puts rows back: Recycle Bin first, else a backup the user picks | Site rows | Yes, after a dry run with counts |
| Uninstall | Backs up, then removes all that the made list names | Site, Power Automate (hand steps), the record | Yes: the user types the app name |

The function lists below are an agent recommendation (2026-11-14), not approved.

Diagnose functions: D1 installed record against the newest version; D2 schema compare (lists, columns, types, choices, indexes, views, list settings); D3 permission compare; D4 required settings rows; D5 empty required lookups and item counts against the 5,000 view threshold; D6 flow health from rows the flows write; D7 backup age and counts; D8 hand checks (co-owner, sharing, connections).

Restore functions: R1 Recycle Bin restore; R2 pause flows before, resume after; R3 fresh backup before any write; R4 dry run with counts; R5 load in dependency order and remap lookup IDs; R6 resolve Person fields, report missing accounts; R7 verify, then clear the pause. Version 1: an empty list, or missing rows only; no overwrite of rows.

What an app supplies: one schema file; a settings list with standard keys (app version, schema version, flows paused, test mode); a health list and a heartbeat step in each flow; the backup folder.
