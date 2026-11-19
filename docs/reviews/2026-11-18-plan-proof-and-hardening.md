# Plan: proof and hardening (RADE)

Approved by the Administrator on 2026-11-18 ("implement everything we've discussed into the plan for the project at an appropriate stage and do as much as possible to test these issues in the next rounds"). Scope: RADE; items that belong to an app are marked "app session". This file is the one home of the plan: [docs/NEXT_PROMPT.md](../NEXT_PROMPT.md) and the handoff detail link here. A row marked **Decide** needs the Administrator before it is built. After a restart, continue from the first row that is not done.

Why this plan: on 2026-11-18 the build was ahead of its proof (18 engine releases in 5 days; one app; one person who has run it; no device result after R29b r5 on engine-v14). The stages below put proof and integrity before new features. Engine and app work go on beside it (the Administrator, 2026-11-18).

## Stage 0: built with this plan (engine-v19)

| Item | What | Proof |
|---|---|---|
| 0.1 Probe without Bypass | The child check ("RADE can run its scripts") runs its test script a second time with no `-ExecutionPolicy` setting and adds `, without Bypass [ran]` or `[blocked, exit code N]` to its detail. The result of the check does not change. The probe takes out the setting that a RADE started from its shortcut hands down to child processes, so its answer is the computer's own. | tests/engine_test.sh (one new line, with that setting handed down to every run); a device round, stage 1 |
| 0.2 No-reconnaissance check | [scripts/no_recon.py](../../scripts/no_recon.py): a word search of the engine sources and the sample app in both check lanes; the app canary prints a NOTE line for each such word in a real app's built bundle. A word search, not a proof. | `NORECON files=26 hits=0`; self-test 18 found, 6 allowed |
| 0.3 Security brief | Draft for the ISSM and other reviewers, a private Claude doc (not in this public repo). | The Administrator reads and sends it |

## Stage 1: the next device round (the Administrator runs it; 90-161.Z R31 on engine-v19)

Read these lines in the round's results. Each one answers a question of this plan. The app's session moves the lock to engine-v19 first.

| Line in the results | Question | If the answer is bad |
|---|---|---|
| `Test script ran, policy [...], without Bypass [ran]` | Does the work computer need `-ExecutionPolicy Bypass` at all? `[ran]` = no. The `policy [...]` part names what Group Policy sets (no such part = it sets none). | `[blocked ...]`: the setting stays; say so in the brief, with the policy named |
| The language-mode check (Local group) | Is PowerShell in Full Language mode? Constrained Language Mode would stop the window. | The window cannot run: text mode only; stage 5 becomes urgent |
| `Layout self-check: PASS layout` at 150 % | Do the header (R29b V1), the step timer (N3) and the 900 px text column (engine-v18) draw right on a real screen? | Fix, release, next round |
| 4 lines `PASS shared files` | Do the install records work on Windows PowerShell 5.1? | Fix, release, next round |
| R29a (download and saved-address steps) | No result yet since engine-v14 | Run it in the same sitting |

Also in this round, by hand (2 minutes): paste the bundle once in the console and once in ISE, and note whether both start. Stage 2.2 needs to know that ISE and the console behave the same before the hash check is built.

## Stage 2: integrity (what a user copies is what was reviewed)

| Item | What | Who | State |
|---|---|---|---|
| 2.1 Ruleset on main | Require a pull request and the status check `checks` (the name GitHub shows for the job of check.yml). Also from the standards close-out: the Dependabot secret for the name denylist, private vulnerability reporting. | The Administrator (GitHub settings) | Open |
| 2.2 Bundle hash | [docs/specs/bundle-hash.md](../specs/bundle-hash.md): one short hash on the page and on the bundle's first screen. | Agent, after the answers | **Decide**: the five questions (agent REC: take all five RECs) |
| 2.3 Tagged releases on the page | The page serves an app's tagged release, not `main`, with a "previous version" choice: a merge is then not a release, and a rollback is one click. | Agent (page), app session (tags) | **Decide** with 2.2 (its Q4) |
| 2.4 Remove Bypass | If stage 1 shows `[ran]`: take `-ExecutionPolicy Bypass` out of the 4 places (04-steps.ps1, 07-checks.ps1, 05-installed.ps1, window/07-run.ps1), no fallback; the probe goes with it. One engine release, one round. | Agent | Waits for stage 1 |
| 2.5 Release number guard | release.yml compares `ENGINE_RELEASE` with the tag. | Agent | **Decide** (guard file) |
| 2.6 Code signing | Ask whether a DoD code-signing certificate can be had (the brief asks it). | The Administrator | Open |

## Stage 3: code (failures must not vanish)

One or two items for each engine release, in this order. Each has a test before it merges.

| Item | What | Source |
|---|---|---|
| 3.1 Saved checks can fail in silence | A hidden error ends the whole save (finding 10) | [strict-mode findings](2026-11-17-strict-mode-findings.md) |
| 3.2 The 11 strict-mode faults | Fix; then run the window, test-round and maintenance paths under strict mode (never run so far) and list what they show | same file, "Limits" |
| 3.3 Discarded errors | 105 catches give no reason (rule X7). Add reasons or handle the error; the count only goes down | tests/bundle_layout_test.py `SILENT_CATCHES` |
| 3.4 One test for each guardrail | NIPR name, site prefix, site rights, one install per site; and a results e-mail draft with a planted invented name that must come out masked | threat model gap 5 |
| 3.5 Strict mode on | After 3.2 and a clean device round | standards mapping PW.6 |
| 3.6 Drawn proof at 125 % and 150 % | Today CI draws at 100 % and the rest is arithmetic; find out whether the Windows job can set the scale | handoff item 17 |
| 3.7 Keep the output of a failed check run | The failure of 18 Nov was never explained because its output was lost | standards close-out |

## Stage 4: authority

| Item | What | Who |
|---|---|---|
| 4.1 Send the brief | The Administrator has discussed paste-and-run with the ISSM and other professionals (DECISIONS 2026-11-18); the brief asks for the position in writing | The Administrator |
| 4.2 A person reviews the code | A named reviewer of the receiving unit, with [docs/review-guide.md](../review-guide.md); findings become issues (STIG APSC-DV-003170, -001460) | The Administrator asks; agent fixes |
| 4.3 Official endorsement | The long-term goal (the Administrator, 2026-11-18): an approved way to distribute, so RADE does not depend on the paste path staying open | The Administrator |
| 4.4 Threat model at each release | Read [docs/threat-model.md](../threat-model.md) at each engine release and say so in the release notes | Agent |

## Stage 5: operations (run it for other people)

| Item | What | State |
|---|---|---|
| 5.1 Diagnose | First of the four missing maintenance run types: "is my install healthy" for files, the site record and, through the app's steps, its flows | **Decide**: the function list (handoff item 8) |
| 5.2 Uninstall, Restore, Back up | The undo that makes a deploy safe at another unit | After 5.1 |
| 5.3 Feedback inside the boundary | When the results e-mail ends, no failure at another unit reaches the owner. Design a results row on a list of the owner's own site, inside DoD365 (the boundary rule allows it) | **Decide**: design first |
| 5.4 Flow ownership | A flow belongs to the account that imported it, and only the installing account can update (docs/engine.md "Guardrails"). Add a hand step "add a second owner", and a way for a new person to take over an install | App session; RADE: the take-over path with 5.1 |
| 5.5 Flow health after import | A check that the flow is on and its connections are valid | App session (step), RADE (shows it) |
| 5.6 Drift check | docs/drift-check.md: also the place to see a data-policy change that turns a flow off. The ISSM sees the field list first | Handoff items 4 and 7 |

## Stage 6: scale and continuity

| Item | What | State |
|---|---|---|
| 6.1 A second person | 2 or 3 people paste and run with no help from the owner; record where each one stops | The Administrator, after stage 1 |
| 6.2 A second app | The smallest planned app, to test "RADE knows a platform, never an app's objects" | **Decide**: which app |
| 6.3 A second maintainer | A second account with review rights, and a one-page take-over document | **Decide** |
| 6.4 Repo access review | Each quarter, recorded in docs/DECISIONS.md (STIG APSC-DV-003000) | Agent, first on 2027-02-18 |
| 6.5 A second channel | If the work proxy blocks the page's host, no install is possible. Decide whether a copy on a SharePoint page is wanted | **Decide** |
| 6.6 Release rhythm | Agent REC: one engine release for each device round, so each release has a device result | **Decide** |

## Not taken

- A pause of engine work until the device rounds are done (agent REC, 2026-11-18): the Administrator works on the engine and the app together.
- A two-week freeze of the kit (agent REC, 2026-11-18): no answer; not in this plan.
