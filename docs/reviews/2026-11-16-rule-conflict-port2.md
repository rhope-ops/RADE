# Rule conflict check: delta kit port (kit pull requests 19 to 25)

Date: 2026-11-16 (America/Chicago). Reviewer: `reviewer` subagent, fresh context, strong tier (opus, set on the call; the author's tier).
Brief: the kit's text in `.claude/skills/rule-change/SKILL.md` "Conflict check", with the changed lines below, the whole AGENTS.md and docs/DECISIONS.md.

## Changed lines

- "Handoff" bullet: + "Steps: `.claude/skills/handoff/SKILL.md`."
- "one line each where possible" -> "one line per rule (...); a rule that needs more lines is a procedure."
- `scripts/bloat_check.py` bullet: + "A run slower than its baseline: `.claude/skills/efficiency/SKILL.md`."

## Findings (none MAJOR)

1. Conflict: `efficiency` skill "Check lanes: `scripts/check.sh --record` after a full-lane pass" (one run) against the DECISIONS row "`timings.check.seconds` ... becomes the median of 3 full-lane runs on main". Fix: the check-lane path uses the median of 3 (`bloat_check.py --compare check=<median> --record`).
2. Gap: `efficiency` cites "(the Administrator, 2026-11-16)" for "warn only" with no row. Closed: the port row in docs/DECISIONS.md (2026-11-16) records it; the reviewer read DECISIONS before that row was written.
3. Conflict: `handoff` skill "Open ... each with what done is" and "Needs the Administrator: each ... with its options and the recommendation" against the DECISIONS row "one line per open item in docs/NEXT_PROMPT.md". Fix: add "one line each" in the skill.
4. Overlap: "the current request overrides the handoff" in Order of authority, the Handoff rule and the `handoff` skill. Fix: one place, pointers elsewhere.
5. Overlap: "Read docs/NEXT_PROMPT.md" in "Start of session" and the `handoff` skill. Fix: the skill points to "Start of session".
6. Overlap: AGENTS.md "one line per rule" against `audit` item 12 "Prefer one line per rule". Fix: item 12 points to the AGENTS.md line.

Status: findings 1, 3 to 6 go to the Administrator before the merge.

rule-conflict-check: 5a5b94a0763f
