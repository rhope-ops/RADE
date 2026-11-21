<!-- Sync: this top part mirrors the RADE page (index.html, Ready card). The part between the "apps" marks is written by
     scripts/build_readme.py --write from apps.json, each app's manifest and the page's steps; the full check fails when it is old. -->
# RADE

Test, deploy, enjoy · Teams: **RHOPE-OPS**

For a computer that cannot open the RADE page (https://rhope-ops.github.io/RADE): the same content, with links on github.com.

<!-- >>> apps: generated from apps.json by scripts/build_readme.py --write (do not edit) -->
## 90-161.Z

**Test round R40**

### Copy the script for 90-161.Z.

Round R40 r1: window r13 with 4 checks, the reopen check on the screen you closed it on, and the look questions. Fake data.

`90161Z-R40-round-r1.ps1`<br>
1,186,619 bytes, 13,068 lines<br>
Script check: `da516687bfa9...509e`, the stored hash ([.sha256.json](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R40-round-r1.ps1.sha256.json)). The RADE window shows the same value in its title bar.

| Link | What to do |
| --- | --- |
| **[Copy script](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R40-round-r1.ps1)** | Select "Copy raw file" (the copy button at the top right of the code). Then do the steps below. |
| **[Open as .txt](https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R40-round-r1.ps1)** | The script as plain text, to read before you paste. Ctrl+S saves it as a .txt file; Ctrl+A, then Ctrl+C copies it. |
| **[Tasks for this application](https://github.com/rhope-ops/90-161.Z)** | The 90-161.Z repository: its tasks and round scripts. |

If one link is blocked on your network, try the other.

1. Start menu: type ISE and open Windows PowerShell ISE as yourself (not "Run as administrator").
2. File > New. Click in the white script pane. Press Ctrl+V, then F5.
3. The RADE window opens. Do what it says.

For help, ask in the Teams channel **RHOPE-OPS**.
<!-- <<< apps -->

[Repository](https://github.com/rhope-ops/RADE)

# Details

Deploy and test applications on a locked-down work computer from one pasted PowerShell window: checks, files, steps and a results e-mail.

The RADE page (the work bookmark): https://rhope-ops.github.io/RADE ([index.html](index.html), applications in [apps.json](apps.json)).

Engine requirements, and how an application gets the engine (by commit, with no RADE checkout): [docs/engine.md](docs/engine.md). Make an application for RADE: [docs/make-an-app.md](docs/make-an-app.md). Manifest contract: [schemas/rade-manifest.schema.json](schemas/rade-manifest.schema.json).

Agents: read [AGENTS.md](AGENTS.md) first. Status: [docs/NEXT_PROMPT.md](docs/NEXT_PROMPT.md). Decisions: [docs/DECISIONS.md](docs/DECISIONS.md). Log: a private document (AGENTS.md "Project rules").

New to working with AI agents? Read [docs/WORKING_WITH_AGENTS.md](docs/WORKING_WITH_AGENTS.md).

## Build and test

- Build, test and lint commands: [AGENTS.md](AGENTS.md) "Commands".
- How the engine is built and released: [docs/engine.md](docs/engine.md).
- Make an application for RADE: [docs/make-an-app.md](docs/make-an-app.md).
- Code standard: [docs/code-standard.md](docs/code-standard.md) and its RADE extras, [docs/code-standard-rade.md](docs/code-standard-rade.md). Review guide: [docs/review-guide.md](docs/review-guide.md).
- Threat model: [docs/threat-model.md](docs/threat-model.md). Proposed bundle hash display: [docs/specs/bundle-hash.md](docs/specs/bundle-hash.md).
- Report a vulnerability: [SECURITY.md](SECURITY.md).
