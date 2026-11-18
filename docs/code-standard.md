# Code standard

Decided by the owner, 2026-11-17 (docs/DECISIONS.md): all code is lean, modular, commented and human-editable, and stays so as work continues. Why: a person must be able to read any script and know what it does before they run it. [scripts/code_standard.py](../scripts/code_standard.py) enforces the rules marked **(check)**; the fresh reviewer of each pull request checks the rules marked **(review)**.

The kit owns this file and the check. A project gets both by sync, or by a hand port where its rules forbid sync; it sets its own caps, scope and stricter rules (for example full docs per function) in its own `.code-standard.json` and a section below, never in a copy of the check.

## Scope

- Every file git tracks with the extension `.py`, `.ps1`, `.psm1`, `.js`, `.mjs`, `.cjs` or `.sh`, and every file with no extension whose first line is a shell or Python shebang (for example scripts/git-hooks/pre-push).
- Generated files get rule C6 only (their source gets the other rules). The list is `config.generated` in [.code-standard.json](../.code-standard.json).

## Rules

| No. | Rule | How |
|---|---|---|
| C1 | Each source file starts with a header comment: what the file is for, its inputs, its outputs and how to run it. Python: the module docstring. | **(check)** at least 60 characters; **(review)** the content |
| C1 safety | Opt-in: a project sets `"c1_safety": true` in its `.code-standard.json` "config". Then each source file's header also has the three labels `Network:` (the hosts it reaches, or "none"), `Writes:` (the files, lists or sites it changes, or "none") and `Credentials:` (what it asks for and how, or "none"), so a reviewer finds them before a run. Each label must start a header line (after only comment characters and spaces, for example `# Network: none.`) and have a value after it on that line; a label inside a sentence does not count. | **(check)** [scripts/code_standard_gate.py](../scripts/code_standard_gate.py); **(review)** true |
| C2 | Each function has a comment that says what it does. One line is enough; full parameter docs are not required. Python: a docstring, or a `#` line directly above the `def` or before its first statement. Shell and JS: a comment line directly above. The file header and a divider line (`# ----`) do not count. | **(check)** present; **(review)** true and useful |
| C3 | A function is at most 60 lines long. A longer job is split into named steps, each its own function. | **(check)** |
| C4 | A file is at most 600 lines long. A larger program is split into modules, one concern each. | **(check)** |
| C4 line | Opt-in: a project sets `max_line_chars` in the "caps" of its `.code-standard.json` "config". Then the longest line of each hand-written file, counted in characters, is at most that many (a long line is hard to read and review). Generated files and generated blocks are skipped, as for the other rules. | **(check)** the debt value is the file's longest line and may only go down |
| C5 | One function lives in one file. A copy that must also run alone is generated, between marker lines `# >>> <name>: generated from <source> ...` and `# <<< <name>`. | **(check)** same body twice fails |
| C6 | A generated file says `GENERATED` in its first 15 lines and names its source and the command that builds it. | **(check)** |
| C7 | Names say what a thing is or does: Python `snake_case`; PowerShell `Verb-Noun`; no one-letter names except loop counters and short lambdas. | **(review)** |
| C8 | A comment says why or what, in plain English, and is true. Remove a comment the code makes obsolete in the same change. | **(review)** |
| C9 | No magic values: a fixed number, path, address or limit is a named constant with a comment that says where it comes from. | **(review)** |
| C10 | Each Python and PowerShell file parses. | **(check)** |
| C2 full | Opt-in: a project sets `"c2": "full"` in its `.code-standard.json` "config". Then each function longer than 10 lines also documents each parameter and its return value, in the form its language's own help tools read. Python: a docstring with an `Args:` section that names each parameter (not `self` or `cls`) and a `Returns:` section when it returns a value (PEP 257). PowerShell: comment-based help (.SYNOPSIS or .DESCRIPTION) with one `.PARAMETER` per parameter, placed where `Get-Help` finds it (about_Comment_Based_Help). JavaScript: a `/** */` JSDoc block directly above, with one `@param` per parameter and `@returns` when it returns a value. Shell: the C2 comment only. | **(check)** [scripts/code_standard_docs.py](../scripts/code_standard_docs.py); **(review)** true and useful |
| C11 | Lean: no dead code, no unused option, no second way to do the same job; prefer the standard library over a new dependency. A change does not make a check run slower than its baseline (.claude/skills/efficiency/SKILL.md). | **(review)**; time: `scripts/check.sh` TIME line |

## The ratchet

- `.code-standard.json` `debt` lists the violations that existed when a repo adopted the standard (empty in the kit). A violation not in that list fails; a listed function or file that grows fails.
- A listed item that is fixed also fails until the same change lowers the baseline (`--update`, which refuses new debt). So the list can only shrink.
- A rule turned on later (for example `"c2": "full"` or the cap `max_line_chars`): `--adopt` lists its current debt once, in the same change as an owner row (below). The comparison with main accepts that list only when the option was off on main, so an option that is already on cannot be adopted again. A stricter form of a rule that is already on is adopted the same way when the config's level is raised above the one on main (`"c1_safety": 2` for the strict safety check). It never touches the debt of a rule the ratchet already holds.
- The owner row: a table row that the change adds to docs/DECISIONS.md (a line that starts with `|`), whose decision cell names `.code-standard.json` and whose By cell is the owner role from the `- Owner:` line of AGENTS.md as it is on the merge base (a change cannot name its own owner) and nothing else (a note in brackets may follow). The row has exactly four cells (write `\|` for a `|` inside a cell), so a spare cell cannot move the By cell. The row must be new, and the change must leave every older row as it was: a row that is on main already (moved or re-spaced) is refused, and a change that edits or removes an older row cannot open the gate at all, so an old decision cannot be turned into a new one. Correct or mark an older row in a change of its own. The check compares the file with its text on the merge base line by line; it reads no diff output, no date, and compares no text for likeness. After main moves, fetch origin/main before the check, or main's own row edits count as this change's. Limit: the check reads what the row says, not who wrote it; a false row is a matter for review. A By cell with `scripts/`, `.py`, `agent` or `delegation` (any case) is refused, and so is a line that is not a table row; the check prints which rule refused it. Only an owner row opens the gate for a cap or scope change or for an adopted list.
- New files meet the rules: a debt key for a file that does not exist on the merge base is refused, even with an owner row. A renamed or moved file is new by this rule and starts clean.
- Never add an item to the baseline by hand, raise a cap or add an `exclude` to pass (AGENTS.md "Checks"). The check compares the baseline with the one on the merge base with origin/main; a cap or scope change needs an owner row.

## Commands

- Check: `python3 scripts/code_standard.py` (scripts/check.sh runs it in both lanes). Pass = last line `CODE-STANDARD pass`.
- Every measurement: `--report`. Lower the baseline after a fix: `--update`. A project's first baseline: `--init`. A rule just turned on: `--adopt`. Prove the check: `--test`.

## RADE extras

The Administrator, 2026-11-17. The text above is the kit's core, ported by hand from rhope-ops/archimedes_lever `docs/code-standard.md` (no kit sync, AGENTS.md "Project rules"); change it only by a port. This section adds RADE's stricter rules. Apps built on RADE use it too: rhope-ops/90-161.Z links here.

Turned on in [.code-standard.json](../.code-standard.json) "config" (docs/DECISIONS.md 2026-11-17): `"c2": "full"` (rule C2 full: full docs for each function longer than 10 lines) and `"c1_safety": true` (rule C1 safety: `Network:`, `Writes:` and `Credentials:` lines in each header) and `"max_line_chars": 200` in the caps (rule C4 line; docs/DECISIONS.md 2026-11-17, stricter checker). Their starting debt is in the baseline and only shrinks.

| No. | Extra rule | How |
|---|---|---|
| X1 | The C1 header also names the run target (for example Windows PowerShell 5.1). | **(review)** |
| X2 | Engine PowerShell runs on Windows PowerShell 5.1 (AGENTS.md "Project rules"). Embedded PowerShell lives in `.ps1` files, never in a Python string, so the PowerShell parser and the check can read it. | **(check)** C10 parse; **(review)** the 5.1 target |
| X3 | A generated bundle starts with a table of contents, and each part has a banner with its source file and SHA-256. | **(review)**; tests/engine_test.sh |
| X4 | A decision in a comment names who decided and the date (for example "the Administrator, 2026-11-17"). | **(review)** |
| X5 | A fixed number, path, address or limit is a named constant or a manifest value. | **(review)** |
| X6 | When a change touches a function in the debt list, fix that function in the same change if it is small; otherwise leave it no worse. Kit files: fix them in the kit, then port. | **(review)** |
| X7 | A discarded error says why: `catch { $null = $_ }` has a comment on the same line that gives the reason (for example `# history is a convenience: never stop a round for it`). A `try` around a cmdlet uses `-ErrorAction Stop`, or the catch never runs for that cmdlet's errors. New engine code is written to run under `Set-StrictMode -Version 2`; the shipped engine does not turn strict mode on until a work-computer round has passed with it ([strict-mode findings](reviews/2026-11-17-strict-mode-findings.md)). | **(check)** the first sentence: tests/bundle_layout_test.py counts the catches with no reason (106 of 129 on 2026-11-17); the constant `SILENT_CATCHES` may only go down; **(review)** the rest |

- Each rule's link to NIST SP 800-218 (SSDF) and the DISA Application Security and Development STIG: [standards-mapping.md](standards-mapping.md).
- How a reviewer in another unit inspects a RADE app before it runs: [review-guide.md](review-guide.md).
- Check in this repo: `python3 scripts/code_standard.py` (scripts/check.local.sh runs it and its `--test` in both lanes).
