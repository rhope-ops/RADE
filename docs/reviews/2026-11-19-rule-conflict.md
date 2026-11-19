# Rule conflict check: shorter project rules (2026-11-19)

Short record: only project rules changed (`.claude/skills/rule-change/SKILL.md` "Conflict check", point 4). The two rules marked "(cannot be changed)" ("No reconnaissance", "DoD365 boundary") are word for word as before.

## Changed lines

Ten lines of AGENTS.md "Project rules": Project log, Engine source, App repos, RADE and the app, No code fetch at run time, Windows PowerShell 5.1, Personal-data guard, Public repo, Code standard, Window. Before and after, in full: the text of the pull request. The aim is the same meaning in fewer bytes (session load ~4,985 to ~4,906 tokens; cap 5,000).

## Status

Draft by the agent. The Administrator has not approved the text yet: AGENTS.md "Rule text" needs the Administrator's approval of the exact text, which the pull request shows in full.

## Fresh review of the first draft (commit 8fb4df3)

A fresh reviewer (the `reviewer` subagent, the author's model tier) compared each old and new line. 1 MAJOR, fixed in the second draft: "Code standard" had lost its duty ("all code is modular, clearly commented and human inspectable"); the words are back. MINOR, fixed: "Windows PowerShell 5.1" keeps "must run" and "and"; "Project log" keeps "log entries never go in"; "Personal-data guard" keeps "this repo runs the". MINOR, left for the Administrator to decide:

- "Engine source" drops the gloss "(the engine/ folder and the RADE logo)". docs/engine.md "How an app gets the engine" lists the files, but docs/reviews/2026-11-17-rule-conflict.md records the gloss as approved text.
- All ten lines drop "the Administrator," and the older of two dates from the bracket; the two fixed rules keep the old form, so the section has two bracket forms.

## Step 1 result (search for the same topic)

- No rule is added or removed and no topic is new. The reviewer found no script, skill or document that reads an old line, and the rule labels are unchanged, so the citations in docs/standards-mapping.md and docs/code-standard-rade.md still resolve.
- Result: no conflict found.

rule-conflict-check: 532eea5ddfcf
