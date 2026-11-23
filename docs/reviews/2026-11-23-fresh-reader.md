# Fresh-reader test: release and handover steps (2026-11-23)

- File: [docs/RELEASE_AND_HANDOVER.md](../RELEASE_AND_HANDOVER.md) (new in the fleet v2 engine-v36 pull request).
- Method: `.claude/skills/instructions/SKILL.md` "Fresh-reader test". Each round: a new `reviewer` subagent (same model tier as the author) that read only that file, with the brief of the skill. After each round the marked steps were rewritten and `scripts/check_instructions.py` gave 0 findings.
- Readers: 5 rounds, each a new agent.

| Round | Steps marked "yes" (blockers) | What changed after the round |
|---|---|---|
| 1 | 20 (all three sections) | Wait until the run stops (not only green); one action per step; the Teams channel named; the release number shown again; `gh` login and a git clone in place of "a copy"; the role words of the handover made one ("you") |
| 2 | 7 | `gh` 2.49.0 or higher (the `attestation` command); the answers of `gh auth login`; the new person's account name asked first; the handover written for a repository of a personal account (page **Collaborators**, no role **Admin**, no move of the repository) |
| 3 | 4 | The Git credentials question and the Enter key of `gh auth login`; the Google e-mail address asked first; the denylist shared before the long wait for a release; an engine pull request named by its title |
| 4 | 2 | The browser part of the login in its real order (sign in, **Device Activation**, **Continue**, **Authorize github**); commands to delete the folder **rade-check** |
| 5 | 5 (1 not real) | The number of the newest engine pull request written down, so a new one can be seen; the new person added to the Teams channel. Not real: "a Windows clone changes line ends" (`.gitattributes` keeps LF for `*.py`, so the hash matches) |

Result: the marks that block went from 20 to 4 real ones in round 5, and the round-5 fixes are in the file. Open "minor" points (not blockers): the install of `gh` is one step with no sub-steps; "at the top" holds for the newest release only; the remote watch of the new person's run (a screen share) is not named. A round 6 was not run: the next change to this file runs it again.
