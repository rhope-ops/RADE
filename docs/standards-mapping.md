# Standards mapping: RADE

Self-assessment by the project, 2026-11-17 (the Administrator asked for it). It is not an ATO artifact, a STIG checklist result or an assessment by an authorizing official. Its purpose: a reviewer in another unit can see which published practice each RADE rule supports, and where RADE has no control yet.

Sources (read from the published files, 2026-11-17):
- NIST SP 800-218, Secure Software Development Framework (SSDF) version 1.1, February 2022: https://doi.org/10.6028/NIST.SP.800-218
- DISA Application Security and Development STIG, Version 6, Release 5, benchmark date 30 Sep 2026 (file `U_ASD_STIG_V6R5_Manual-xccdf.xml`, from the DoD Cyber Exchange STIG downloads). IDs are given as rule version (APSC-DV-…) and Group ID (V-…).

Status words: **Met** (a RADE rule or check does it), **Partial** (part of it, or by review only), **Gap** (nothing yet; a REC says what would close it), **N/A** (the item is about a part RADE does not have, for example a web server).

## 1. Each code-standard rule and what it supports

Rules: [code-standard.md](code-standard.md).

| Rule | SSDF practice / task | STIG item |
|---|---|---|
| C1 header, C1 safety (Network, Writes, Credentials) | PW.5.1, PW.7.2 | APSC-DV-003215 (V-222653) coding standards; APSC-DV-003110 (V-222642) supports the review for embedded authentication data |
| C2 comment, C2 full docs | PW.5.1, PW.7.2 | APSC-DV-003215 (V-222653); APSC-DV-003170 (V-222648) code review |
| C3 function length, C4 file size | PW.5.1, PW.7.2 | APSC-DV-003215 (V-222653) |
| C5 one function in one file | PW.4 (reuse instead of duplicating), PW.5.1 | APSC-DV-003215 (V-222653) |
| C6 generated banner; X3 bundle parts with SHA-256 | PS.2.1 | APSC-DV-003140 (V-222645) files hashed before deployment |
| C7 names, C8 comments, C9 named values; X4, X5 | PW.5.1 | APSC-DV-003215 (V-222653) |
| C10 each file parses; X2 Windows PowerShell 5.1 target | PW.7.2 (code analysis by a tool) | APSC-DV-003215 (V-222653) |
| C11 lean (no dead code, no second way, standard library first) | PW.4.1, PW.4.4 | APSC-DV-003215 (V-222653) |
| The ratchet (shrink-only baseline, check in both lanes) | PO.4.1, PW.7.2 | APSC-DV-003190 (V-222650) flaws are tracked |

## 2. NIST SSDF practices

| Practice | Status | Where RADE does it, or REC |
|---|---|---|
| PO.1 Define Security Requirements for Software Development | Partial | AGENTS.md "Project rules" (No reconnaissance, DoD365 boundary, Windows PowerShell 5.1, Public repo) state the limits. The [engine.md](engine.md) "Guardrails" stop honest mistakes and are not security controls (engine.md says so). REC: one list of security requirements |
| PO.2 Implement Roles and Responsibilities | Partial | AGENTS.md "Authority" and "Delegation" (the Administrator decides; author, worker and fresh reviewer roles). REC: name a security reviewer role for releases |
| PO.3 Implement Supporting Toolchains | Met | scripts/check.sh and scripts/check.local.sh (both lanes), scripts/code_standard.py, scripts/pii_guard.py, the pre-push hook |
| PO.4 Define and Use Criteria for Software Security Checks | Met | `CHECK PASS` lanes; `CODE-STANDARD pass`; the merge gate in AGENTS.md "Delivery" and "Checks" |
| PO.5 Implement and Maintain Secure Environments for Software Development | Partial | Cloud sessions with a host allowlist; no credentials in the repo (AGENTS.md "Untrusted input"). REC: record the environment settings in one doc |
| PS.1 Protect All Forms of Code from Unauthorized Access and Tampering | Partial | GitHub; pull requests; the pre-push hook blocks every force-push, the deletion of main, and runs the full lane for a push to main. REC: a branch ruleset on main when the plan allows it |
| PS.2 Provide a Mechanism for Verifying Software Release Integrity | Met | [engine.md](engine.md) "How an app gets the engine": signed file list (build attestation), SHA-256 of every engine file, apps check each hash |
| PS.3 Archive and Protect Each Software Release | Partial | Tagged releases `engine-v<N>` with `rade-engine.sha256`. Gap: no SBOM (PS.3.2). REC: list the one external module (PnP.PowerShell, by version) in each release |
| PW.1 Design Software to Meet Security Requirements and Mitigate Security Risks | Gap | REC: a short threat model in engine.md (what a pasted bundle can reach, and what stops it) |
| PW.2 Review the Software Design to Verify Compliance with Security Requirements and Risk Information | Partial | Plans and fresh reviews before merge (AGENTS.md "Delegation") |
| PW.4 Reuse Existing, Well-Secured Software When Feasible Instead of Duplicating Functionality | Met | C5, C11; only the installed modules (Windows PowerShell 5.1, PnP.PowerShell) |
| PW.5 Create Source Code by Adhering to Secure Coding Practices | Met | [code-standard.md](code-standard.md) with its check |
| PW.6 Configure the Compilation, Interpreter, and Build Processes to Improve Executable Security | Partial | The build fetches by commit and checks SHA-256; interpreted code. REC: name `Set-StrictMode` use in the X rules if the Administrator wants it |
| PW.7 Analyze Human-Readable Code to Identify Vulnerabilities and Verify Compliance with Security Requirements | Met | Fresh review of each code change; scripts/code_standard.py; the PowerShell parser (C10) |
| PW.8 Test Executable Code to Identify Vulnerabilities and Verify Compliance with Security Requirements | Partial | tests/engine_test.sh, the app canary, the Windows job (.github/workflows/window.yml), work-computer rounds. No security-specific tests. REC: one test per guardrail in [engine.md](engine.md) |
| PW.9 Configure Software to Have Secure Settings by Default | Partial | Guardrails are always on (NIPR name check, site prefix, one install per site), but they stop honest mistakes, not attacks (engine.md "Guardrails"); from ENGINE_RELEASE 13 the reach test sends no Windows sign-in to the tested address |
| RV.1 Identify and Confirm Vulnerabilities on an Ongoing Basis | Gap | REC: a "report a problem" line in the review guide that names the Teams channel (no address; AGENTS.md "Public repo") |
| RV.2 Assess, Prioritize, and Remediate Vulnerabilities | Partial | Review findings by severity; MAJOR blocks a merge |
| RV.3 Analyze Vulnerabilities to Identify Their Root Causes | Partial | Misses are logged in the private project log |

## 3. DISA ASD STIG V6R5 items that apply to how RADE is built

Only the items about development, code and delivery are listed. Items about web servers, sessions, SOAP, SAML, cross-site scripting and similar web parts are N/A: RADE is a pasted PowerShell script with a local window.

| STIG item | Status | Where RADE does it, or REC |
|---|---|---|
| APSC-DV-003215 (V-222653) The application development team must follow a set of coding standards. | Met | [code-standard.md](code-standard.md), checked by scripts/code_standard.py |
| APSC-DV-003170 (V-222648) An application code review must be performed on the application. | Met | A fresh reviewer for each code change before merge (AGENTS.md "Delegation") |
| APSC-DV-003190 (V-222650) Flaws found during a code review must be tracked in a defect tracking system. | Partial | Findings live in the pull request and docs/reviews/; code debt in .code-standard.json. REC: open a GitHub issue for each MAJOR finding not fixed in the same pull request |
| APSC-DV-003110 (V-222642) The application must not contain embedded authentication data. | Met | scripts/pii_guard.py (DoD tier) scans every push and pull request for secrets; sign-in is interactive (`Connect-PnPOnline -UseWebLogin`); C1 safety names the credentials of each file |
| APSC-DV-003140 (V-222645) Application files must be cryptographically hashed prior to deploying to DoW operational networks. | Met | Engine file list with SHA-256, signed at release; each bundle part has a banner with its SHA-256 (X3) |
| APSC-DV-001430 (V-222513) The application must have the capability to prevent the installation of patches, service packs, or application components without verification … | Partial | An app's build checks every engine file's SHA-256; no code is downloaded at run time. Gap: a person cannot yet check the pasted bundle's own hash on the work computer. REC: the review guide gives the steps (Get-FileHash) and each release lists the bundle hash |
| APSC-DV-000650 (V-222444) The application must not write sensitive data into the application logs. | Partial | Results e-mail holds masked counts only (AGENTS.md "Project rules", DoD365 boundary); by review |
| APSC-DV-002530 (V-222606) The application must validate all input. | Partial | Site address prefix guardrail; manifest schema check (scripts/check_manifest.py). Other input by review |
| APSC-DV-002570 (V-222610) The application must generate error messages that provide information necessary for corrective actions without revealing information … | Partial | By review only. REC: add to the review checklist |
| APSC-DV-003235 (V-222656) The application must not be subject to error handling vulnerabilities. | Partial | By review only |
| APSC-DV-003130 (V-222644) Prior to each release …, tests plans and procedures must be created and executed. | Met | release.yml runs the checks before each release; each app's work-computer round has a written test plan (for example rhope-ops/90-161.Z docs/gov-test-plan.md) |
| APSC-DV-003150 (V-222646) At least one tester must be designated to test for security flaws in addition to functional testing. | Partial | The fresh reviewer checks rule conflicts and security; no named tester |
| APSC-DV-003230 (V-222655) Threat models must be documented and reviewed for each application release … | Gap | REC: as PW.1 |
| APSC-DV-003010 (V-222632) A Software Configuration Management (SCM) plan … | Partial | AGENTS.md "Delivery" and "Git safety" describe change control; not one SCM plan document |
| APSC-DV-003000 (V-222631) Access privileges to the Configuration Management (CM) repository must be reviewed every three months. | Gap | REC: a quarterly check of repo collaborators, recorded in docs/DECISIONS.md |
| APSC-DV-003180 (V-222649) Code coverage statistics must be maintained for each release of the application. | Gap | REC: decide whether coverage is worth measuring for PowerShell (Pester) |
| APSC-DV-001460 (V-222515) An application vulnerability assessment must be conducted. | Gap | REC: an assessment by the receiving unit's ISSO, with this file and the review guide as input |
| APSC-DV-002630 (V-222614) Security-relevant software updates and patches must be kept up to date. | Partial | RADE uses only what the work computer has installed; module updates belong to the computer's owner |
