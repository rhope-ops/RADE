# Fresh-reader test: the run steps of every bundle (E1), 2026-11-25

- Files: `engine/rade_parts.py` (`RUN_STEPS`: the first lines after the hash line of every bundle and its .txt copy; 90-161.Z R43 E1).
- Reader: the `reviewer` subagent, a fresh context each round, same model tier as the author; it saw only the steps as the person sees them.

| Round | Marked steps | Fix |
|---|---|---|
| 1 | 2 ("as yourself", which Start menu item), 4 (pane named by its color, early F5), 5 (no failure path) | The ISE item named, x86 and Run as administrator excluded; paste and F5 split; a failure step |
| 2 | 1 (focus in the address bar), 2 ("the x86 one"), 4 (which tab), 5 (what "the end" is), 6 (where to send, how to copy) | Click in the text first; the full item name; the new tab; step 5 shows the exact last line; the Teams channel by name |
| 3 | 6 (no action after the taskbar), 7 (no red text: step cannot be done; red text can hold folder names), 8 (minor) | The taskbar click; the failure step only asks for help in the Teams channel and says not to paste the red text |
| 4 | 5 (the same line is also in the header, so an early F5; medium), 4 and 6 (minor wording) | "at the bottom of the script pane"; "the top pane (the script pane)"; "the RADE window". No MAJOR mark left |

Known limit: the steps are on the page the person copies from; after step 2 that page is behind Windows PowerShell ISE. The PFM chose the place (E1: steps at the top of the .txt copy).

Result: round 4 has no MAJOR mark; its marks are fixed in the text as listed. Proof for the text itself: `tests/bundle_layout_test.py` check 1b (first lines, ASCII, no `#>`, step 5 names the real last line).
