# Standards plan: close-out (RADE)

Written 18 Nov 2026 (America/Chicago) by the session that ran the plan. The plan and the Administrator's choices are in
docs/DECISIONS.md (rows of 17 Nov 26). This file lists what is merged, what proved it, and every point left open.

## Merged

| Stage | Pull request | What | Proof |
|---|---|---|---|
| 1 Engine security fixes | 87 | No Windows sign-in to any address the engine asks; host rule with port; build stops on a missing part | Full lane; `NETRULES pass`; Windows job; released as engine-v14 (783dee4) |
| 3 Checker | 88 | Safety labels at line start with a value; owner-row gate; no debt for new files; line cap 200 | Full lane; five fresh reviews of the gate |
| 4 Repo baseline | 88 | .gitattributes, .editorconfig, SECURITY.md, Dependabot, lint settings file, pinned checkout in pii-guard.yml | Full lane; `--sha` unchanged |
| 5 Error handling | 94 | Rule X7; count of discarded-error catches with no reason (106 of 129) | Full lane; `LAYOUT pass=10 fail=0` |
| 6 Windows PowerShell 5.1 | 95 | Job text51: a text-mode run of the sample bundle | Green on 5.1.26100: `TEXT51 pass=10 fail=0` |
| 7 Design | 94 | docs/threat-model.md; docs/specs/bundle-hash.md (proposed) | Fresh review of each file reference |

Device evidence: rhope-ops/90-161.Z docs/reviews/2026-11-18-r29b-results.md records round R29b r5 on engine-v14 (RADE
checks 9 passed, layout self-check PASS). R29a, which uses the download and saved-address steps, has no result yet.

## For the Administrator (GitHub settings; an agent cannot do these)

- Ruleset "protect main": require a pull request and the status check `scan` (not `window`, not `text51`: they run only for some paths).
- Save the name denylist as a Dependabot secret `PII_GUARD_DENYLIST` (decision of 17 Nov 26), or Dependabot pull requests fail `scan`.
- Turn on private vulnerability reporting (SECURITY.md points to it).
- docs/specs/bundle-hash.md has five open questions; nothing is built until they are answered.

## Open points (MINOR findings of the reviews, not fixed)

Engine (for the next release, engine-v15):
- 106 discarded-error catches give no reason (rule X7); 11 strict-mode faults are listed in docs/reviews/2026-11-17-strict-mode-findings.md.
- The two blank-address refusals (hand step, step run) and the download's sign-in setting are proved by text search only.
- A step with `urlConfig` needs its own `url` (the build stops): confirmed by the Administrator on 18 Nov 26 (docs/DECISIONS.md).
- The file read behind the newer-version line has a 4-second limit that fails without a word (05-installed.ps1).

Checker gate (scripts/code_standard_gate.py):
- An old decision row edited in place passes when its old line is kept elsewhere in the file (for example in an HTML comment).
- A stale local origin/main can hide a missing owner row; CI is the backstop.
- Tests do not kill three changes: the file named outside the decision cell, an empty owner, the working file read as text.
- The gate reads what a row says, not who wrote it (the accepted limit, in docs/code-standard.md).
- The kit (archimedes_lever) must take the four checker files at its next port.

Tests and CI:
- tests/text_mode_51.py: an error the engine catches itself (`STOPPED:`) fails only the result-line checks, not the error checks; one docstring line of `run_text` is stale.
- The full lane failed once on 18 Nov right after the text-mode test was added and passed the next five times; the output of
  the failed run was not kept. A fresh reviewer found no cause in the new test (6 runs, 3 under load). Not explained.
- tests/net_rules_test.sh needs `bc`.
- scripts/check.sh does not re-run the checker self-test when only code_standard_gate.py changes (guard file: the Administrator decides).
- scripts/check.local.sh skips lint in the fast lane when only PSScriptAnalyzerSettings.psd1 changes.

Docs:
- SECURITY.md states a scope and a supported version that the Administrator did not word.

## Process notes

- The orchestrator was this session's model, not a separate Opus 5.5 session: a session in plan mode cannot start a working
  child session, and a scheduled-task session had no access to the repositories.
- A wrong check name in the plan (`pii-guard` for `scan`) blocked pull request 86 until the Administrator removed the ruleset.
- Fresh reviews found real faults in every code change, three of them in the orchestrator's own fixes.
