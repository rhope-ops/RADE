# Rule conflict check: kit 2026.11.20.1 sync (2026-11-18)

Steps: `.claude/skills/rule-change/SKILL.md` "Conflict check". Reviewer: the `reviewer` subagent in a fresh context, Opus tier (the same tier as the author). It got only the changed lines, AGENTS.md, docs/DECISIONS.md and the brief of the skill.

## Changed lines ("Project rules", against origin/main)

- Changed: "Code standard": it now names docs/code-standard.md and docs/code-standard-rade.md (it named "the kit core plus the RADE extras").
- Removed: "No kit sync (the Administrator, 2026-11-15)".
- The Administrator approved both exact texts in the question dialog on 2026-11-18 (docs/DECISIONS.md).

## Findings

No MAJOR finding. The MINOR findings below are recorded; they do not change rule text (rule-change skill, step 3):

1. "(cannot be changed)" against "Administrator changes": the kit's "Hard rules" intro already says that a hard rule changes only by a change of its text. This is kit text.
2. "App repos": is a release tag a "live or irreversible effect"? The rule is older than this change and was not changed here.
3. DECISIONS row of 2026-11-16 (start-read budget 4,500 tokens): the cap is now 5,000, and 4,500 is only a warning. A future row should name that row as replaced.
4. DECISIONS row "kit defects": it said "syncs from kit main". Corrected in this change (the row is new here) to "the kit commit that holds the fix".
5. The DECISIONS row of 2026-11-15 "No kit sync" is not marked as replaced. The new row of 2026-11-18 lists it under "Replaces"; older rows are not edited (docs/code-standard-rade.md, Administrator row).
6. Overlap between "Public repo" and the hard rule "Secrets and personal data" (e-mail addresses and ID numbers). Both are older lines and were not changed here.

rule-conflict-check: 99775727c79c
