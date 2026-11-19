# Spec: bundle hash display

Status: approved 2026-11-18 (the Administrator: "take all five RECs"); built in engine release 21 and on the page; the stop in the bundle (R6) waits for one work-computer round (Q5) · Owner: the Administrator · Updated: 2026-11-18

## Goal
A person who pastes a bundle can check, in seconds and with no tool, that the text in front of them is the text that was built and reviewed: the same short hash shows on the bookmark page, in the stored release data, and on the bundle's first screen.

## Done
For one app, the build prints and stores the SHA-256 of each bundle; the page shows its short form beside the Copy button and compares it with the stored value; the first screen of the pasted bundle prints the same short form; a changed byte changes all three.

## Requirements
- R1. Each app build prints the SHA-256 of each built bundle, and stores it in a small JSON file beside the bundle (`<bundle>.sha256.json`: file name, SHA-256, build id, engine release) or in the app's release. Open: where (question Q1).
- R2. The bookmark page ([index.html](../../index.html)) computes the SHA-256 of the text it fetched, in the page, with Web Crypto (`crypto.subtle.digest`, no library), and shows the first 12 and the last 4 hex characters beside the Copy button. It compares the full value with the stored value from R1 and says "matches the stored hash" or "does not match: do not run it".
- R3. The bundle prints the same short hash on its first screen (text mode and window): "Script check: 3f9a1c07b2de...c41e". Window (the Administrator, 2026-11-19): nothing shows when it matches; on a mismatch the boot, Choose and Ready cards show a dark red last line, "This script does not match its hash. Do not run it." ([window-design.md "Title bar"](../window-design.md)); the title bar no longer carries the hash.
- R4. The hashed text is fixed: UTF-8 bytes of the bundle with line ends as LF, from the first byte after the marked header line (R5) to the end. The bundles are ASCII already (rade_build.py refuses other text), so no byte-order mark question arises. The page hashes the text it copies after the same normalization; Windows PowerShell ISE may turn LF into CRLF on paste, so the bundle normalizes before it hashes.
- R5. The chicken-and-egg problem: a hash written inside the text it covers cannot be right. So the build writes the hash outside the hashed part: one marked header line (`# @@BUNDLE-HASH <64 hex> @@`) that holds the value, and the hash covers everything after that line. The bundle can then read the line, hash the rest and compare.
- R6. When the page or the bundle finds a mismatch it says so in plain words and stops (the bundle: before it does anything else).

## Out of scope
- Code signing (no certificate; no agent handles one). See [threat-model.md](../threat-model.md).
- Proof that anyone reviewed the code.
- Hash display for the engine files (the lock does that: engine.md "How an app gets the engine").

## How the bundle can know its hash
| Way | Good | Bad |
|---|---|---|
| A. The build writes the value into the header line (R5) | Simple; no run-time work; the page and the stored JSON agree by construction | The line is not covered; a changed bundle can keep the old line and still print it. The bundle shows it, but cannot prove it |
| B. The bundle hashes its own text at run time (everything after the header line) and prints the result | The printed value follows the text actually pasted, so a changed bundle prints a different value | Needs the bundle to find its own text (`$MyInvocation` is empty for pasted text in ISE: it may need `$psISE.CurrentFile.Editor.Text`, and nothing in the console host); a changed bundle can also change this code to print the old value |
| C. Both: print B, compare with the A line, say "checked" or "does not match" | The person sees a mismatch between the line and the text | Same limit as B against a bundle that was changed with care |

Proposal: C, with R5 (hash the text after the marked line). The first-screen line is a check for honest mistakes (a stale page, a half copy), like the guardrails: it is not a security control against a person who changes the code.

## What this proves and what it does not
- It catches a change on the way (the clipboard, a stale or cached page, a half copy, a different version of the file).
- It does not prove that anyone reviewed the code. The hash says "the text is the one that was built"; the review ([review-guide.md](../review-guide.md)) says what the text does.
- A changed page can lie: it can show a hash that fits a changed bundle. The person must compare the short value with one from a second place (the stored JSON in the release, read on another computer, or the line in the team's notes).
- A changed bundle can print any value. Only the second place, outside the pasted text, is evidence.

## Edge cases and errors
- E1. The browser has no `crypto.subtle` (an http page, an old browser): the page shows no hash and says "hash not available"; the Copy button still works.
- E2. The stored JSON is not there (older build): the page shows the computed value and says "no stored value to compare".
- E3. Line ends: the page, the build and the bundle all normalize to LF before the hash.

## Decisions
| ID | Decision | By | Date | Alternatives rejected, and why |
|---|---|---|---|---|
| D1 | Q1: the stored value is a JSON file beside each bundle in the app's repo (`<bundle>.sha256.json`), written by the build; the release notes follow when the page serves tagged releases | the Administrator | 2026-11-18 | Release only: the page could not compare for `main` |
| D2 | Q2: the short form is the first 12 and the last 4 hex characters | the Administrator | 2026-11-18 | First 8 only: weaker against a made-up near match |
| D3 | Q3: way C: the bundle hashes its own text, prints the value and compares it with its first line | the Administrator | 2026-11-18 | A or B alone |
| D4 | Q4: the page serves a tagged release instead of `main`, as a separate step (plan "proof and hardening", 2.3) | the Administrator | 2026-11-18 | Stay on `main` |
| D5 | Q5: built now; one work-computer round proves that a paste in ISE hashes the same text | the Administrator | 2026-11-18 | Wait for the round before building |

As built (agent choices inside the decisions; say so if one is wrong):
- Until the round of D5, a mismatch in the bundle is shown and stops nothing (R6 for the bundle is not on yet): a false alarm from a paste would block every round. The page does stop (no Copy button).
- The bundle shows the line in text mode (second line), in the round's log and report, and, only on a mismatch, as the red last line of the window's boot, Choose and Ready cards (window-design.md "Title bar"; the short form left the title bar on 2026-11-19).
- The bundle reads its own text from its file (the saved runner, a `-File` run) or from the ISE script pane. Pasted into a plain console it cannot, and says "not available".
- The page: a script with no hash line is offered as "an older build" only when no stored file is there; a stored file that cannot be read, or that differs, is a mismatch. The script and its stored file are two downloads, and the host can hand out an old copy of one for some minutes after a push, so that card says to wait 5 minutes and try again before it says "do not run" (not measured: a risk to watch at the first app release).
- Blank lines above the first line are allowed (R4 says "from the first byte after the header line"); a script of an older build has no hash line, and the page says so.

## Questions (answered 2026-11-18: each REC is taken; see Decisions)
- Q1. Where is the stored value? REC: a JSON file beside each bundle in the app's repo, written by the build (the page already reads from the app repo), and also in the release notes once the page serves tagged releases. Alternative: release only (fewer files, but the page cannot compare for `main`).
- Q2. Which short form? REC: first 12 and last 4 hex characters (a person reads 16 characters; a mismatch in any part of the text changes both ends). Alternative: first 8 only (shorter; weaker against a made-up near match).
- Q3. Way A, B or C for the bundle? REC: C (print the run-time hash and compare with the header line).
- Q4. Should the page serve a tagged release instead of `main`? REC: yes, as a separate step: the hash is only worth reading when the page has a release to compare with.
- Q5. Does it go in the next engine release or wait for a work-computer round to prove that the ISE paste hashes the same text? REC: build it, but prove the paste in one round first (the console host and ISE differ on `$MyInvocation`).
