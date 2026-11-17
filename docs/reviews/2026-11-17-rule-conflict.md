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
