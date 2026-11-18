# How to review a RADE app before you run it

For a reviewer in another unit (an ISSO, a client systems technician or a developer) who must decide whether a RADE app is safe to paste into a work computer. You need no programming background for parts 1 to 3. Part 4 needs a computer with git and Python 3 (not a work computer).

RADE is the runner that every app carries; the app is the part that does one job (for example rhope-ops/90-161.Z). Both are public on GitHub, so everything below can be read before anything runs.

## 1. What the code may do

Read these first. Each is short.

| Read | It tells you |
|---|---|
| RADE [AGENTS.md](../AGENTS.md) "Project rules" | The fixed limits: no network reconnaissance, no data across the DoD365 boundary, no code download at run time, Windows PowerShell 5.1 only |
| [engine.md](engine.md) "Guardrails" | What RADE checks before it writes anything (NIPR computer name, the SharePoint address prefix, one install per site) and what each check reads |
| The app's AGENTS.md "Project rules" | The app's own limits (for 90-161.Z: no government data in the repo; its "Commands" section: credentials only through Get-Credential at run time) |
| [threat-model.md](threat-model.md) | What can go wrong with a pasted bundle, what limits it today and the open gaps (a self-assessment) |
| [standards-mapping.md](standards-mapping.md) | Which NIST SSDF practices and DISA ASD STIG items the project meets, in part or not yet (a self-assessment, not an ATO artifact) |

## 2. Check that the bundle is the reviewed code

A bundle is one `.ps1` file that a person pastes. Each app keeps its bundles in its repo (90-161.Z: `scripts/gov/paste/`).

1. On GitHub, open the bundle file in the app repo, select "History", and note the commit you review.
2. On the work computer, before you paste, download the bundle file with the browser (the "Raw" button, then "Save as") and run:
   `certutil -hashfile <file> SHA256`
   (`Get-FileHash -Algorithm SHA256 <file>` gives the same value where that command exists; it was not found in one Windows PowerShell 5.1 test job: the comment in engine/ps/03-files.ps1, Save-RoundDownload.) Do not copy the text into an editor and save that: an editor can change the line ends or add a byte-order mark, and then the value differs although the code is the same.
3. Download the same file from that commit on another computer and run the same command (or `sha256sum`). The two values must be the same. If they differ, do not run it. A match proves only that the text did not change on the way; it does not prove that anyone reviewed it. That is what part 3 is for.
4. The bundle starts with a table of contents. Each part has a banner with its source file and that file's SHA-256 (code standard rule X3). The RADE engine parts must match the engine release the app's lock names (`scripts/rade.lock.json` in the app; the release lists every engine file's SHA-256 and is signed: engine.md "How an app gets the engine").

## 3. Read the code

Every source file starts with a header (code standard C1). Look for three lines in it:

- `Network:` the hosts it reaches, or "none".
- `Writes:` the files, lists or sites it changes, or "none".
- `Credentials:` what it asks for and how, or "none".

A header is a claim, not proof: check it against the code. Files from before 2026-11-17 may not have these lines yet (they are listed as debt in `.check.state.json` and are being fixed); for those, and to check any header, search the file for:

| Look for | PowerShell | Python | JavaScript |
|---|---|---|---|
| Network | `Invoke-WebRequest`, `Invoke-RestMethod`, `WebRequest`, `WebClient`, `HttpClient`, `Connect-PnPOnline`, `Proxy` | `urllib`, `http.client`, `requests`, `socket` | `fetch`, `http`, `goto`, `XMLHttpRequest` |
| Writes | `Set-`, `Add-`, `New-`, `Remove-`, `Out-File`, `WriteAll`, `Copy-Item`, `Move-Item` | `open(` with `w` or `a`, `write_text`, `os.remove`, `shutil` | `writeFile`, `mkdir`, `unlink` |
| Credentials | `Get-Credential`, `UseDefaultCredentials`, `DefaultCredentials`, `-UseWebLogin` | `getpass`, `token`, `password` | `token`, `password` |
| Runs other code | `Start-Process`, `powershell.exe`, `Invoke-Expression`, `& {`, `-ExecutionPolicy` | `subprocess`, `exec(`, `eval(` | `child_process`, `eval(` |

A value that is set in another file (for example a `$...Url` variable) must be followed to where it is set; in a bundle, search the whole bundle, not one part. `UseDefaultCredentials` sends the user's Windows sign-in to that address without a prompt: check that each such address is a fixed, expected host.

Each function has a comment above it or in it that says what it does (rule C2). Rule C2 full asks more of a function longer than 10 lines: help that names what it takes and gives back (`.SYNOPSIS` and one `.PARAMETER` per parameter in PowerShell, in a `<# ... #>` block). That rule is new: most engine functions do not have that block yet (the open count is the "docs" debt in `.code-standard.json`), so for them read the `#` lines and the code. Read help in the file as text. Do not dot-source or run a file to read its help: that runs its code.

Checklist for the rules a script cannot check ([code-standard.md](code-standard.md), marked **(review)**):

- [ ] The header and help are true: the code does what they say and nothing more.
- [ ] No host is contacted other than those in `Network:` (and never a scan, ping or port check).
- [ ] No password, token or key is in the text; sign-in is interactive.
- [ ] The Windows sign-in is sent (`UseDefaultCredentials`) only to fixed, expected hosts, never to an address read from a file a user can change.
- [ ] Error messages tell the user what to do and do not show internal data.
- [ ] Nothing is written outside what `Writes:` names.
- [ ] Names say what a thing does (PowerShell Verb-Noun), and fixed values are named constants.

## 4. Run the project's own checks (optional)

Do this only after parts 2 and 3: the checks run the repo's code, build every app (it downloads the app repos from GitHub) and run the bundle tests in PowerShell.

On a throwaway computer or virtual machine with git, Python 3 and PowerShell 7 (the checks are code from the repo too, so do not run them on a computer you depend on):

```bash
git clone https://github.com/rhope-ops/RADE && cd RADE && scripts/check.sh
```

Pass = the last line is `CHECK PASS`. It runs the code standard check (`python3 scripts/code_standard.py`), the personal-data and secret scan, the engine tests and the build of every app. Do the same in the app's repo.

## 5. Report a problem

Use the project's Teams channel (named in the app's help text). Do not send government data, names or site addresses in the report.
