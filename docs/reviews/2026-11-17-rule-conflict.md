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
