# Rule conflict check: 2026-11-17, Code standard line (kit checker port)

Fresh-context check of the rule line changed against origin/main (`.claude/skills/rule-change/SKILL.md`, "Conflict check"). Reviewer: `reviewer` subagent, model Opus (the author's tier), given the old and new lines, AGENTS.md, docs/DECISIONS.md and docs/code-standard.md.

## Changed line

- `-` "Code standard (the Administrator, 2026-11-17): ... per docs/code-standard.md; tests/check_code_standard.py enforces it, and its baseline may only shrink."
- `+` "Code standard (the Administrator, 2026-11-17): ... per docs/code-standard.md (the kit core plus the RADE extras, full docs per function included); scripts/code_standard.py enforces it, and its baseline may only shrink." The Administrator approved this exact text on 2026-11-17.

## Result

No conflict between two rules. Findings and what was done:
1. The 2026-11-17 "Code standard" row still named the old checker and baseline file: marked "Partly replaced" by the "Code standard, layered" row.
2. The kit text said "A project gets both by sync", against the rule "No kit sync": the kit spec now says "by sync, or by a hand port where its rules forbid sync" (kit change), and this repo's copy was refreshed.
3. "Baseline may only shrink" now has one Administrator-gated case: `--adopt` writes the first list of an opt-in rule (C2 full, C1 safety) with a DECISIONS row; the check refuses it for a rule that was already on at main. Overlap with AGENTS.md "Checks", not a conflict. A wording change of the line is left to the Administrator.
4. "Full docs per function" is wider than C2 full (functions longer than 10 lines): the approved text is kept; docs/code-standard.md gives the exact scope.
5. The reviewer read an older copy of scripts/code_standard.py; the copy in this change equals the kit's (OPT_IN check).

rule-conflict-check: b5f3df44c24c
