# Rule conflict check: 2026-11-17, Start after checks

Fresh-context check of the rule line changed against origin/main (`.claude/skills/rule-change/SKILL.md`, "Conflict check"). Reviewer: `reviewer` subagent, model Opus (the author's tier), given only the changed lines, AGENTS.md and docs/DECISIONS.md.

## Changed line

- `-` "RADE and the app (the Administrator, 2026-11-14): ... it installs apps and does not start them. ..."
- `+` "RADE and the app (the Administrator, 2026-11-14; 2026-11-17): ... it installs apps, and after its checks pass, its Start button opens an installed app from that app's local copy (no download). ..." The Administrator approved this exact text on 2026-11-17 (asked by the 90-161.Z session).

## Result

No conflict between two rules. Findings:
1. The replaced decision row of 2026-11-14 ("RADE installs apps only; it does not start them.") was still in the live table. Fixed in this pull request: moved unchanged to docs/decisions-archive.md.
2. Overlap, wording only: "(no download)" in the new line says the same as the rule "No code fetch at run time". Kept, because the Administrator approved the exact text; the two agree.
Checked consistent: DECISIONS rows of 2026-11-17, docs/engine.md "Starting the app", docs/window-design.md, the 2026-11-15 row "No launcher that downloads an app's code at run time", No reconnaissance, DoD365 boundary. Reviewer's note: "never an app's objects" is read as site and app data, not the app's start script (an inference; the docs do not define "objects").

rule-conflict-check: b1cf0f9ca647

---

## Rule conflict check: code standard line, 2026-11-17

Changed line (`python3 scripts/bloat_check.py --rules`):

+ Code standard (the Administrator, 2026-11-17): all code is modular, clearly commented and human inspectable, per docs/code-standard.md; tests/check_code_standard.py enforces it, and its baseline may only shrink.

Reviewer: fresh `reviewer` subagent, Opus tier, given only the changed line, AGENTS.md, docs/DECISIONS.md and the brief of `.claude/skills/rule-change/SKILL.md`.

Findings (no MAJOR):
1. docs/code-standard.md said a change to the check is made in both repos; the "App repos" rule says a RADE session never edits an app repo. Fixed: a change is made here and a 90-161.Z session ports it.
2. Kit-file debt "fixed in the kit first" vs the ratchet's "fix a small listed function in the same change". Fixed: the ratchet bullet excepts kit files.
3. The "Engine source" rule names engine/rade_build.py; after the approved engine split the engine is the engine/ folder. Open: a new exact text goes to the Administrator for approval (rule lines change only with approval).
4. Overlap: C6 repeated AGENTS.md "Checks" (never hand-edit generated files). Fixed: C6 links to "Checks".
Minor: C10 named "the lint", which RADE does not have. Fixed: removed.

rule-conflict-check: 156ac6e2880a

---

## Rule conflict check: "Engine source" line, 2026-11-17

Changed line (`python3 scripts/bloat_check.py --rules`), text approved by the Administrator (17 Nov 26):

- Engine source (the Administrator, 2026-11-14): engine/rade_build.py here. Apps fetch it by commit and check each file's SHA-256 (docs/engine.md "How an app gets the engine").
+ Engine source (the Administrator, 2026-11-14; 2026-11-17): the engine/ folder here (entry engine/rade_build.py; file list: docs/engine.md "How an app gets the engine"). Apps fetch it by commit and check each file's SHA-256.

Reviewer: fresh `reviewer` subagent, Opus tier, given only the changed lines, AGENTS.md, docs/DECISIONS.md and the brief of `.claude/skills/rule-change/SKILL.md`. No MAJOR finding.

1. "the engine/ folder" vs the file list, which also holds assets/logo/logo-rho-128.png. Open: a wording change goes to the Administrator (rule text).
2. "Apps fetch it" vs "No code fetch at run time": different moments (the app's build vs the runner). Open: same.
3. Overlap with "App repos" (both point to docs/engine.md). No change.
4. docs/engine.md and docs/window-design.md named only engine/rade_build.py. Fixed: both point to engine/ps.
5. DECISIONS row of 2026-11-14 placed `$helpChannel` in engine/rade_build.py. Fixed: a dated note names engine/ps/09-start.ps1.

rule-conflict-check: e1ad6b78cbec

---

## Rule conflict check: "Engine source" (answer 1A) and "Lint" lines, 2026-11-17

Changed lines (`python3 scripts/bloat_check.py --rules`), texts approved by the Administrator (17 Nov 26): "Engine source" names the files docs/engine.md lists (the engine/ folder and the RADE logo) and "Apps' builds fetch them"; "Lint" names scripts/lint.sh.

Reviewer: fresh `reviewer` subagent, Opus tier, given only the changed lines, AGENTS.md, docs/DECISIONS.md and the brief. No MAJOR finding.

1. The pass string: lint.sh printed "LINT bundles=n findings=n". Fixed: its last line is now "LINT findings=n".
2. "check.local.sh runs it when engine files change": it runs with the engine tests (the full lane, or a change to engine/, tests/, schemas/, assets/ and a few others). Open: a wording change needs the Administrator's approval.
3. Overlap with "Verification" (run the checks in Commands) and "Checks" (do not run by hand a lane the hook runs next): already there for every command; lint adds one case. Open: same.
4. Overlap: the 5.1 syntax part of the lint enforces part of "Windows PowerShell 5.1". Open (optional pointer): same.
5. The replaced "Engine source" decision row was still in the table. Fixed: moved unchanged to docs/decisions-archive.md.

rule-conflict-check: 05fabac151f0
