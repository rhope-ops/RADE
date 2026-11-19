# How to make an app for RADE

What an application repository must hold so that RADE can test and deploy it. RADE owns the computer and the run; the app owns the product and the site ([engine.md](engine.md) "RADE and the app"). Working example: rhope-ops/90-161.Z. Small sample: [../schemas/examples/sample-manifest.json](../schemas/examples/sample-manifest.json) with [../tests/fixture-app](../tests/fixture-app).

## What the app repo holds

| # | Item | What it is | Example in rhope-ops/90-161.Z |
|---|---|---|---|
| 1 | Manifest | One JSON file: an `application` block and a list of `bundles`. Contract: [../schemas/rade-manifest.schema.json](../schemas/rade-manifest.schema.json). Default path `scripts/paste_bundles.json`. | `scripts/paste_bundles.json` |
| 2 | Step scripts | PowerShell files (Windows PowerShell 5.1) that a bundle writes to the computer and runs. They follow the step contract ([engine.md](engine.md) "Step contract"). | `scripts/gov/*.ps1` |
| 3 | Lock | The RADE commit and every engine file with its SHA-256 ([engine.md](engine.md) "How an app gets the engine"). Copy it from a RADE release (`rade-engine.lock.json`). | `scripts/rade.lock.json` |
| 4 | Build script | Downloads the locked engine files, checks each SHA-256 and runs `engine/rade_build.py --app-root <repo>`. Copy the example; it uses the Python standard library only. | `scripts/build_paste_bundles.py` |
| 5 | Built bundle | The engine's output: one `.ps1` text for each bundle and, from engine-v21, its stored hash `<bundle>.ps1.sha256.json` (the RADE page compares with it), both committed to the repo. Never edit them by hand. | `scripts/gov/paste/*.ps1`, `*.ps1.sha256.json` |
| 6 | `go.md` on main | The task page. The window reads it to tell the user that a newer round exists. | `go.md` |
| 7 | `rade-release.json` on main | The current version of each app in the manifest, for the newer-version notice in a deploy. | `rade-release.json` |

## The manifest

- `application` (all required): `name` (shown in the window), `folder` (the app's folder under `OneDrive\RADE`), `prefix` (starts file names and the e-mail subject), `repo` (`owner/name` on GitHub), `home` (the app's page), `own` (file patterns the app owns; clean-up may recycle only these), `knownDirs`.
- `application.logo` (optional): the path in your repo of your app's logo, a PNG (128 px square is enough). The window shows it at 64 px under the RADE logo, with your app's name beside it in gray, once the user chooses your app. The build stops if the file is missing or is not a PNG. Until the run-time logo (docs/specs/run-time-logo.md) is built, the PNG travels in the bundle as text (the Administrator, 2026-11-18).
- Each bundle (required: `out`, `round`, `title`, `files`, `steps`, `collect`): one round. `files` are written to the computer, `steps` run in order, `collect` names the result files for the e-mail draft. Optional: `app`, `fetch`, `cleanup`, `apps`, `release`.
- Each entry of `apps` (required: `name`, `summary`, `steps`): optional `mode`, `version` (required for a deploy), `marker` and `start`. `start` is a script in the app's local install folder, as a path with `/` between folders (for example `App/Start-App.ps1`, plain names only, ending `.ps1`; the schema checks it). After the checks pass, the Ready screen of an installed app shows a Start button that runs it in its own `powershell.exe` process, with the folder as its working folder, and then RADE closes. Nothing is downloaded: the script is a bundle file or one an install step puts there. Without `start` there is no button. The button is the main one when the installed version is the bundle's version; when the bundle is newer, Install stays the main one.
- Each step (required: `name`, `dir`, `file`): a script step, or `kind: guide` for a step the user does by hand. `needs` names the RADE checks the step depends on.
- Hand steps (R31): show only the buttons that lead to a different result (`hide`), let a step that only asks questions show them at once (`answersOnly`, with `failOn` for an answer that means a failure), and ask a question only after the answer it depends on (`showIf`): [engine.md "Step contract"](engine.md#step-contract). A script step can say what it does now (`doing`, and `NOW <text>` lines).
- Text lengths: the window has a limit for each text it shows (name, version, summary, step name, step `title`, note, guide line, the number of numbered guide lines, `doneText`, `doing`, `help`): [window-design.md "Text lengths"](window-design.md#text-lengths). The build prints a WARNING line for a longer text.
- The schema is the authority for every field. Check a manifest with `python3 scripts/check_manifest.py <file>` in a RADE checkout.

## Steps

1. Write the manifest and the step scripts. Start from the sample manifest.
2. Copy the lock and the build script from the example and set the lock from the newest RADE release.
3. Run the build script. It writes the bundle; commit the bundle with the manifest.
4. Test the bundle in the app repo: run it in PowerShell 7 text mode with the users folder swapped for a temporary one (the example's `tests/run.sh` shows how). Engine behavior is tested in RADE ([../tests/engine_test.sh](../tests/engine_test.sh)); an app tests only its own bundle and files.
5. Ask the Administrator to add the app to [../apps.json](../apps.json) (`repo` and `manifest`). The RADE page then offers the last bundle in the manifest.

## Rules

- A RADE session never edits an app repo, and an app session never edits RADE: an engine change is a RADE pull request, then a release, then a lock change in the app.
- No app data, site address, person or ID in a manifest, a script or a result that leaves the computer ([engine.md](engine.md) "Guardrails").
- RADE may know a platform (SharePoint, Power Automate, Word, Outlook), never an app's objects. If an app needs a new check, propose it for RADE; do not build it into a step that other apps then copy.
