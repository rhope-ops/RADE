# Rule conflict check: role word in Project rules (2026-11-23)

- Changed lines: 10 lines of AGENTS.md "Project rules" (Project log, Engine source, App repos, RADE and the app, No code fetch at run time, Windows PowerShell 5.1, Personal-data guard, Public repo, Code standard, Window): "the Administrator" becomes "the Maintainer" in the attribution, and "the Administrator's Google Drive" becomes "the Maintainer's Google Drive". The 2 lines marked "(cannot be changed)" are not changed. Exact text approved by the Maintainer in the session (question dialog, 2026-11-23); docs/DECISIONS.md row of 2026-11-23.
- Step 1 of "Steps" (search for the same topic): AGENTS.md "- Owner: the Maintainer" (kit 11.0.1) is the reason for the change; no other line or header value names the role differently except the 2 locked lines.
- Reviewer: a fresh `reviewer` subagent, strong tier (the author's tier), given only the changed lines, the whole AGENTS.md, the whole docs/DECISIONS.md and the skill's brief.
- Findings: MAJOR 0. MINOR 3, all in docs/DECISIONS.md, fixed in the same change: (1) the decision row now says that "the Administrator" in the 2 locked lines names the same role as the Maintainer; (2) its Replaces cell names the part "Project rules and Commands keep their words" of the kit 11.0.1 sync row (role word only); (3) the header's "By" definition says "the Maintainer", with a note that older rows say "the Administrator" for the same role. No overlaps.

rule-conflict-check: 471d6626c430
