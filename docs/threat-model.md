# Threat model: RADE

Self-assessment by the project, 2026-11-17 (the Administrator asked for it; standards plan Stage 7). It is not an approval artifact, an ATO document or an assessment by an authorizing official. It answers: what can go wrong when a person pastes a RADE bundle into a work computer, what limits it today, and what is open. Related: [standards-mapping.md](standards-mapping.md) (SSDF PW.1, STIG APSC-DV-003230), [review-guide.md](review-guide.md), [engine.md](engine.md).

## What RADE is and what it runs as

RADE is one PowerShell script (a bundle) that a person pastes into Windows PowerShell 5.1 on a locked-down work computer. It runs with the user's own rights: no administrator, no installed service, no code signature. It checks the computer, writes files in the user's OneDrive folder, starts the app's scripts as child processes, and can sign in to the user's own SharePoint site through PnP.PowerShell. Fixed limits: no network reconnaissance, no data across the DoD365 boundary, no code downloaded at run time (AGENTS.md "Project rules").

## What RADE trusts and why

| Trusted | Why it is trusted | What follows if it is wrong |
|---|---|---|
| GitHub (raw files, Pages) | The only place bundle text and engine files come from; a public repo anyone can read | A changed file reaches the user |
| The bookmark page [index.html](../index.html) and [apps.json](../apps.json) | The user opens the page from the work bookmark; the page lists the apps and builds the text to copy | A changed page can send a changed bundle |
| The clipboard between the page and the window | The only way text gets from the browser into PowerShell | Another program can change the text |
| An app's repo, branch `main` | The page reads the bundle from `main` of each app (`base` in index.html: `.../<repo>/main/`), not from a signed release | A merge to `main` is a release to every user |
| The engine release and each app's lock | The lock names a RADE commit and the SHA-256 of each engine file; the app's build checks them (engine.md "How an app gets the engine") | A wrong lock gives a wrong engine, built into a bundle |
| The work proxy | All web requests go through it, with the user's Windows sign-in | It can read what passes |
| The user's CAC sign-in through PnP | `Connect-PnPOnline -UseWebLogin`: interactive, the engine never sees a password | The user acts with their own rights on the site |

## What can go wrong

REC = recommendation, not a decision. Cites are files in this repo.

| Threat | Who could do it | What limits it today | Gap | REC |
|---|---|---|---|---|
| A changed bundle on an app's `main` (the page serves `main`, not a signed release) | Anyone who can merge into the app repo, or whose account is taken over | Pull request, the full check lane and a fresh review ([AGENTS.md](../AGENTS.md) "Delivery", "Delegation"); each bundle part has its SHA-256 in its banner ([code-standard.md](code-standard.md) X3) | A user cannot tell a reviewed bundle from a changed one; the page does not pin a release | Serve a tagged release and show its hash: [specs/bundle-hash.md](specs/bundle-hash.md) |
| A changed bundle between the page and the paste (clipboard) | Malware or a browser add-in on the work computer | None in RADE; the work computer's own protection | Nothing compares the pasted text with what the page fetched | The same spec: short hash on the page and on the bundle's first screen |
| No code signature; step scripts started with `-ExecutionPolicy Bypass` | Anyone who changes a bundle or a step file | Steps are files the bundle wrote itself, with banners and SHA-256s; Group Policy can still block them (engine/ps/07-checks.ps1:348) | Bypass is set in [04-steps.ps1:14](../engine/ps/04-steps.ps1), [07-checks.ps1:164](../engine/ps/07-checks.ps1), [05-installed.ps1:277](../engine/ps/05-installed.ps1) and [window/07-run.ps1:56](../engine/ps/window/07-run.ps1); nothing proves a file is the reviewed one | Code signing (open gap below); until then the bundle hash |
| A saved address file edited by a user | The user, or a program running as the user | `Test-SameHost` ([07-checks.ps1:91](../engine/ps/07-checks.ps1)): the address must be https and keep the fixed host and port; the saved file is read at [07-checks.ps1:72](../engine/ps/07-checks.ps1); the site address must start with the DAF prefix ([engine.md](engine.md) "Guardrails"); no reconnaissance rule | The guardrails stop mistakes, not attacks (engine.md says so) | One test per guardrail (standards-mapping PW.8) |
| The Windows sign-in sent to an address | A step, or a changed address file | `Get-WebRequest` ([07-checks.ps1:111](../engine/ps/07-checks.ps1), engine-v14): sign-in off for the address, only the work proxy gets it; [tests/net_rules_test.sh](../tests/net_rules_test.sh) | An app's own step script can still call any address it likes | Review the app's `Network:` header line ([review-guide.md](review-guide.md) part 3) |
| Personal data in the results e-mail | A user, or a mistaken step | Masked counts only (AGENTS.md "Project rules", DoD365 boundary); `ConvertTo-Masked` ([01-base.ps1:13](../engine/ps/01-base.ps1)); a deploy sends nothing; the e-mail is made as a draft and sent by hand | The app decides what its masking keeps; no test reads a real draft | Review each app's masking; a test with a planted fake name |
| A malicious or mistaken app manifest | An app maintainer | [schema check](../schemas/rade-manifest.schema.json) and `scripts/check_manifest.py`; build asserts in [rade_build.py](../engine/rade_build.py) (for example a step's `needs` must be an earlier step); the step contract (engine.md "Step contract") | A manifest can name any file and address its app owns; the schema cannot judge intent | The review guide part 3; reviewer reads `Network:` and `Writes:` |
| The engine release process | The maintainer account, or a change to the workflow | Manual workflow [release.yml](../.github/workflows/release.yml) from `main`: the checks, a build attestation of the file list, SHA-256 of every engine file | The attestation covers the list of engine files only; the pasted bundle has no published hash | The bundle hash spec |
| Dependence on one maintainer account | Loss, takeover or absence of the account | Public repo; two-lane checks; GitHub ruleset (required check `scan`) | One person can approve and merge; no second reviewer of a release | A second account with review rights; branch ruleset review count when the plan allows |

## Open gaps, in priority order

1. A person cannot check that the pasted bundle is the reviewed one (rows 1, 2 and 8). Design: [specs/bundle-hash.md](specs/bundle-hash.md), proposed, not approved.
2. Code signing is an open gap. The owner has no code-signing certificate and is not sure one can be had. No agent handles a certificate or a key. Until there is a way to sign, `-ExecutionPolicy Bypass` and the unsigned bundle stay.
3. The page serves each app's `main`, not a tagged release.
4. One maintainer account for the repo, the releases and the merges.
5. No test per guardrail, and no test that reads a real results e-mail draft.
6. This model is not yet reviewed at each release. REC: read it at each engine release and say so in the release notes.

This is a self-assessment, not an approval artifact.
