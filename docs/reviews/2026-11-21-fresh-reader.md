# Fresh-reader test: the answer card with choice rows (engine-v35)

Date: 2026-11-21. Rule: AGENTS.md "Instructions people follow"; steps: .claude/skills/instructions/SKILL.md "Fresh-reader test".

- Files: engine/ps/window/08-hand-step.ps1 (`$ui.VAnswer`, the body line of a question card whose choices are full-width rows; E5 of the R42 plan) and docs/window-design.md "A question (yellow)".
- The text is built at run time, so `scripts/check_instructions.py` cannot read it; the context check was done by hand: the line is on the question card, at the time of the choice, on the screen where the click happens.
- Reader 1 (fresh `reviewer` subagent, Sonnet tier), text "Click your answer. You see the next card. Go on.": marked "Go on." (it reads as a second action; the click itself moves on). Its other marks are about the app's headline and choice texts (manifest `answers`), which the app writes: sent to the 90-161.Z session.
- Rewrite: "Click the row with your answer. The click saves it, and you see the next question."
- Reader 2 (a new fresh `reviewer` subagent, Sonnet tier): usable, no blocker; marked that the line does not say the click is final (the card has no Back).
- Fix (a caution before the action): "You cannot change the answer after the click. Click the row with your answer. You then see the next card." ("card", not "question": after the last question the next card is not a question.)
- A planned exception to the step form: the line has no cue ("Go on."), because the click itself moves on and reader 1 read the cue as a second action.
- Result: each marked step of the engine text is fixed. Open: the app's headline should say where the person saw the result (90-161.Z).
