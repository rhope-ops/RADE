# Rule conflict check: 2026-11-16, the guard bullet names the hook (kit port of archimedes_lever#27)

Fresh-context check of the rule line that changed against origin/main (`.claude/skills/rule-change/SKILL.md`, "Conflict check"). The owner approved the new text on 2026-11-16 in the kit decision (rhope-ops/archimedes_lever docs/DECISIONS.md, scope "the kit, then icf-source, RADE, 90-161.Z"); RADE's row: docs/DECISIONS.md, "Kit port by hand of rhope-ops/archimedes_lever#27".

## Changed line

- `+` "The guard (`scripts/pii_guard.py`, on when `.pii-guard` exists) checks every push and pull request, and a PreToolUse hook (`pii_guard.py --hook`, `.claude/settings.json`) checks each outgoing tool call. When it blocks, ..." (rest unchanged)
- `-` the same bullet without the hook clause.

## Reviewer

`reviewer` subagent, model set to Opus (the author's tier), given only the changed lines, AGENTS.md and docs/DECISIONS.md.

Result: no conflict, no overlap, no decision row contradicted. Checked against "Project rules" "Personal-data guard", the guard-file line, "Untrusted input", the DoD365 boundary exception and "a rule a hook or test enforces becomes a pointer to it".

rule-conflict-check: 6f614104cf43
