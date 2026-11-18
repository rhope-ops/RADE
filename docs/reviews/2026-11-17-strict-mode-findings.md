# Strict-mode findings, 17 Nov 26

A list, not a fix (standards plan Stage 5; docs/code-standard.md rule X7). No engine file was changed (`python3 engine/rade_build.py --sha` = 5c079235f63e... before and after). The shipped engine does not turn strict mode on until a work-computer round has passed with it.

## How it was run

1. Build the sample app in a temp folder, as tests/engine_test.sh does: copy tests/fixture-app, copy schemas/examples/sample-manifest.json to `scripts/paste_bundles.json`, run `python3 engine/rade_build.py --app-root <app>`. The deploy bundle is `SAMPLE-R01-round-r1.ps1`.
2. Make the test copy of the bundle with the same `sed` swaps as the `swap` function of tests/engine_test.sh (users root, local go/release files, check gate off, a fake NIPR computer name). Changes to this copy only:
   - first line: `Set-StrictMode -Version 2; ` in front of the bundle's own first line, so every line number below is the line of the built bundle;
   - every `catch { $null = $_ }` prints `CAUGHT@<line>: <message>`, because a strict-mode error inside such a catch is otherwise silent;
   - the final `catch` of engine/ps/11-text-mode.ps1 also prints the line and its text.
3. Run it as the test does, with the answers for the deploy app: `printf '2\n\n\n\n' | USERPROFILE=<temp>/u/test1234 pwsh -NoProfile -File <copy>` (PowerShell 7.x, Linux text mode).
4. The first strict-mode error stops the run (it reaches the final catch). To continue, the temp copy only was patched at that line (an unset variable is set to `$null` first; a missing property is read inside `try`) and the run repeated: 10 rounds. The last run went to the end (`DONE ... Nothing was sent`).

Limits: only the text-mode path of the deploy app ran. The window (needs Windows Forms), the test-round bundle, maintenance and the saved-checks of other apps did not run, so there are more findings than these. Windows PowerShell 5.1 was not used. A line that holds two faults shows once. The run took about 25 minutes of effort; this is an honest partial list.

## Findings (distinct)

Part and line are in the engine file (the bundle line in brackets). "Caught" = a `catch { $null = $_ }` hid it, so the round did not stop.

| No. | Error | Engine part and line | Name | How it showed |
|---|---|---|---|---|
| 1 | The variable cannot be retrieved because it has not been set | engine/ps/02-config.ps1:24 [207] | `$script:configOver` (read in `Get-RadeConfigFile`; only a test sets it) | stopped the run |
| 2 | The property cannot be found on this object | engine/ps/02-config.ps1:94 [277] | `.Step` of a history row, in `Get-LastRoundText` | stopped: the row read has no `Step` (likely a `$null` piped to `Where-Object`, which is one `$null` row; not proved) |
| 3 | same | engine/ps/02-config.ps1:102 [285] | `.Step` of a history row (same cause as 2) | stopped |
| 4 | same | engine/ps/04-steps.ps1:93 and :101 [555, 563] | `.Skipped` of a step result (hash table without that key) | stopped |
| 5 | same | engine/ps/04-steps.ps1:159 [621] | `.Answers` of a step | stopped |
| 6 | same | engine/ps/06-round.ps1:107 [1118] | `.Made` of a step result | stopped |
| 7 | same | engine/ps/06-round.ps1:112 [1123] | `.Answers` of a step result | stopped |
| 8 | same | engine/ps/07-checks.ps1:490 [1724] | `.Advisory` of a check definition (hash table without that key), in `Invoke-Check` | stopped |
| 9 | same | engine/ps/07-checks.ps1:501 [1735] | `.Saved` of a check result | stopped |
| 10 | same | engine/ps/08-saved-checks.ps1:81 [1828] | `.Saved` of a check result | caught: the error is hidden by the function's own catch (line 96), which ends the whole save |
| 11 | same | engine/ps/07-checks.ps1:128 [1362] | `.StatusCode` of a web response | caught: the response of a file address has none; a web address has it |

Not strict-mode errors (they also show with strict mode off, from the test's file addresses and from Linux): `UserAgent`, `UseDefaultCredentials` and `AllowAutoRedirect` on a file request (engine/ps/07-checks.ps1 :115, :116 and :126 [1349, 1350, 1360]) and `[System.Windows.Forms.Clipboard]` (engine/ps/04-steps.ps1:110 [572]).

## What this means

- Real faults (strict mode only shows them; they are wrong today too):
  - 2 and 3: probably a `$null` piped into `Where-Object` (one row), so the code reads a property of `$null`. Today it is harmless because a missing property is `$null`. Fix: `@($Hist) | Where-Object { $_ -and ... }`, or test the list first.
  - 10: the saved-result test `if ($r.Saved)` is hidden by a catch; with strict mode on, the error leaves the loop and the function's own catch ends the whole save of the check results (a fresh-context reviewer proved this with a small pwsh case). Check what it did on 5.1 before you change it.
  - 11: the status code of a response is read in a try with its error discarded; fine, but it hides a real network answer without a code.
- The engine's habit of reading a key that may not be there (4 to 9): result and definition tables are built with some keys left out, then read as `.Key`. Strict mode refuses it. Fix: build each table with every key (a default value), or read with `ContainsKey` / `.PSObject.Properties`. One place per table is better than each reader.
- 1: a variable read before anything sets it (`$script:configOver`). Fix: set it to `$null` in the engine's first part. There are likely more of these in the parts the run did not reach (window, maintenance).
- The 11 findings stop a round at the first one; a work-computer round with strict mode on would give the same. That is why X7 asks strict mode for new code only, and the shipped engine waits. Next engine release: give each table all its keys, set the script-scope variables in 01-base.ps1, then turn `Set-StrictMode -Version 2` on in a test build and run the text-mode tests on Windows PowerShell 5.1 (Stage 6).
- Catches that hide strict errors (10, 11) are one more reason to give each `catch { $null = $_ }` a reason (rule X7; the count is in tests/bundle_layout_test.py).
