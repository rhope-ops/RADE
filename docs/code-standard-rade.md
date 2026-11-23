# Code standard: RADE extras

The Administrator, 2026-11-17. The kit's core is [code-standard.md](code-standard.md) (a kit file: it changes only in rhope-ops/archimedes_lever). This file adds RADE's stricter rules. Apps built on RADE use it too: rhope-ops/90-161.Z links to "RADE extras". Moved here from RADE's copy of code-standard.md at kit 2026.11.20.1 (2026-11-18).

## Settings

Turned on in [.check](../.check) (docs/DECISIONS.md 2026-11-17; the lines moved there from `.code-standard.json` on 2026-11-18): `code-c2: full` (rule C2 full: full docs for each function longer than 10 lines), `code-c1-safety: on` (rule C1 safety, in the strict form below) and `code-max-line-chars: 200` (rule C4 line). Their starting debt is in the baseline and only shrinks. The strict gate enforces the rules of the next section: from kit 11.0.1 the kit's [scripts/code_standard_strict.py](../scripts/code_standard_strict.py), turned on by `code-strict-gate: on` in `.check` (it replaced RADE's own scripts/code_standard_gate.py; docs/DECISIONS.md 2026-11-23); `python3 scripts/code_standard_strict.py --test` proves it (scripts/check.sh runs it).

## Stricter checked rules

| No. | Rule | How |
|---|---|---|
| C1 safety (strict) | Each of the labels `Network:`, `Writes:` and `Credentials:` must start a header line (after only comment characters and spaces, for example `# Network: none.`) and have a value after it on that line; a label inside a sentence does not count. RADE's gate applies this form at `code-c1-safety: on` and at `strict`. | **(check)** the gate; **(review)** true |
| C4 line | The longest line of each hand-written file, counted in characters, is at most `code-max-line-chars` (a long line is hard to read and review). Generated files and generated blocks are skipped, as for the other rules. | **(check)** the debt value is the file's longest line and may only go down |
| The owner row | A change that raises the baseline (an item added, a value raised, an opt-in list adopted) or changes a `code-` line of `.check` needs a table row that the change adds to docs/DECISIONS.md (a line that starts with `|`), whose decision cell names `.check` (the file name itself, not `.check.lock` or `.check.state.json`) and whose By cell is the owner role from the `- Owner:` line of AGENTS.md as it is on the merge base (a change cannot name its own owner) and nothing else (a note in brackets may follow). The row has exactly four cells (write `\|` for a `|` inside a cell), so a spare cell cannot move the By cell. The row must be new, and the change must leave every older row as it was: a row that is on main already (moved or re-spaced) is refused, and a change that edits or removes an older row cannot open the gate at all, so an old decision cannot be turned into a new one. Correct or mark an older row in a change of its own. The check compares the file with its text on the merge base line by line; it reads no diff output, no date, and compares no text for likeness. After main moves, fetch origin/main before the check, or main's own row edits count as this change's. Limit: the check reads what the row says, not who wrote it; a false row is a matter for review. A By cell with `scripts/`, `.py`, `agent` or `delegation` (any case) is refused, and so is a line that is not a table row; the check prints which rule refused it. | **(check)** the gate (`decided`) |
| New files meet the rules | A debt key for a file that does not exist on the merge base is refused, even with an owner row. A renamed or moved file is new by this rule and starts clean. | **(check)** the gate (`new_debt_refusal`) |

## RADE extras

| No. | Extra rule | How |
|---|---|---|
| X1 | The C1 header also names the run target (for example Windows PowerShell 5.1). | **(review)** |
| X2 | Engine PowerShell runs on Windows PowerShell 5.1 (AGENTS.md "Project rules"). Embedded PowerShell lives in `.ps1` files, never in a Python string, so the PowerShell parser and the check can read it. | **(check)** C10 parse; **(review)** the 5.1 target |
| X3 | A generated bundle starts with a table of contents, and each part has a banner with its source file and SHA-256. | **(review)**; tests/engine_test.sh |
| X4 | A decision in a comment names who decided and the date (for example "the Administrator, 2026-11-17"). | **(review)** |
| X5 | A fixed number, path, address or limit is a named constant or a manifest value. | **(review)** |
| X6 | When a change touches a function in the debt list, fix that function in the same change if it is small; otherwise leave it no worse. Kit files: fix them in the kit, then take the kit release. | **(review)** |
| X7 | A discarded error says why: `catch { $null = $_ }` has a comment on the same line that gives the reason (for example `# history is a convenience: never stop a round for it`). A `try` around a cmdlet uses `-ErrorAction Stop`, or the catch never runs for that cmdlet's errors. New engine code is written to run under `Set-StrictMode -Version 2`; the shipped engine does not turn strict mode on until a work-computer round has passed with it ([strict-mode findings](reviews/2026-11-17-strict-mode-findings.md)). | **(check)** the first sentence: tests/bundle_layout_test.py counts the catches with no reason (106 of 129 on 2026-11-17); the constant `SILENT_CATCHES` may only go down; **(review)** the rest |

- Each rule's link to NIST SP 800-218 (SSDF) and the DISA Application Security and Development STIG: [standards-mapping.md](standards-mapping.md).
- How a reviewer in another unit inspects a RADE app before it runs: [review-guide.md](review-guide.md).
- Check in this repo: `python3 scripts/code_standard.py` (scripts/check.sh runs it, and the strict gate's `--test`, in both lanes).
