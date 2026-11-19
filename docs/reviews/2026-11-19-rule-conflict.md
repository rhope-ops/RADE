# Rule conflict check: shorter project rules (2026-11-19)

Short record: only project rules changed (`.claude/skills/rule-change/SKILL.md` "Conflict check", point 4). The two rules marked "(cannot be changed)" ("No reconnaissance", "DoD365 boundary") are word for word as before.

## Changed lines

Ten lines of AGENTS.md "Project rules": Project log, Engine source, App repos, RADE and the app, No code fetch at run time, Windows PowerShell 5.1, Personal-data guard, Public repo, Code standard, Window. Before and after, in full: the text of the pull request. The aim is the same meaning in fewer bytes (session load ~4,985 to ~4,876 tokens; cap 5,000).

## Status

Draft by the agent. The Administrator has not approved the text yet; the merge of the pull request is the approval (lane C).

## Step 1 result (search for the same topic)

- By the author, plus a fresh reviewer on the diff (result in the pull request).
- No rule is added or removed and no topic is new, so no new overlap with "Hard rules", "Defaults" or docs/DECISIONS.md can arise from this change. Each shorter line was compared with its old line for a lost condition.
- Dropped on purpose, as not a rule: the words "the Administrator," in each date bracket (the header names the owner), the older of two dates, and "clearly commented and human inspectable" in "Code standard" (the two linked documents state it).
- Result: no conflict found.

rule-conflict-check: 75ceeed3ec5b
