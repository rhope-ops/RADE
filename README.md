# RADE

Deploy and test applications on a locked-down work computer from one pasted PowerShell window: checks, files, steps and a results e-mail.

**Test, deploy, enjoy.**

## Get an application

The same content as the RADE page (https://rhope-ops.github.io/RADE), for a computer that cannot open github.io. The page always offers the newest script; this section lists the script of 21 Nov 2026, so if a newer round is out, take it from the paste folder (the highest round number).

### 90-161.Z, test round R40

Round R40 r1: window r13 with 4 checks, the reopen check on the screen you closed it on, and the look questions. Fake data.

- Script: `90161Z-R40-round-r1.ps1` (1,186,619 bytes, 13,067 lines).
- Script check: `da516687bfa9...509e`. The RADE window shows the same value in its title bar. Stored hash: [90161Z-R40-round-r1.ps1.sha256.json](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R40-round-r1.ps1.sha256.json).

**[Copy script](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R40-round-r1.ps1)** · **[View as .txt](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R40-round-r1.ps1?plain=1)** · **[Newest scripts (paste folder)](https://github.com/rhope-ops/90-161.Z/tree/main/scripts/gov/paste)**

- Copy script: on the file page, select the copy button ("Copy raw file") at the top right of the code. To save it as a file, select "Download raw file" next to it.
- View as .txt: the file page shows the script as plain text with line numbers, to read before you paste.

1. Start menu: type ISE and open Windows PowerShell ISE as yourself (not "Run as administrator").
2. File > New. Click in the white script pane. Press Ctrl+V, then F5.
3. The RADE window opens. Do what it says.

For help, ask in the Teams channel **RHOPE-OPS**.

## About RADE

The RADE page: [index.html](index.html); its applications: [apps.json](apps.json).

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
