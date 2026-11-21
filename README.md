![RADE: Test, deploy, enjoy](https://repository-images.githubusercontent.com/1457939479/f568bdbc-a8b6-4c15-b151-da1b3b9bffc3)

# RADE
<p><b>Redacted Application Deployment Engine</b></p>

<!-- site:intro -->
Deploy and test applications on a locked-down work computer from one pasted PowerShell window: checks, files, steps and a results e-mail. RADE checks the computer first, saves the application's files, guides you through each step, and keeps a record of the install. After the install, the application works without RADE.
<!-- /site:intro -->

---

### 🔺 Summary

<!-- site:key-facts -->
<table>
<tr><td><b>Checks first:</b></td><td>checks the computer and your site rights before any step; a failed check stops the install.</td></tr> <!-- source: docs/engine.md "Check stages" and "Results" -->
<tr><td><b>NIPR only:</b></td><td>runs only where the computer's full name holds the NIPR domain; elsewhere it stops before it writes a file.</td></tr> <!-- source: docs/engine.md "Guardrails", NIPR only -->
<tr><td><b>Credentials:</b></td><td>CAC sign-on in a browser window for each run; nothing is stored.</td></tr> <!-- source: engine/ps/07-checks.ps1, Connect-PnPOnline -UseWebLogin -->
<tr><td><b>Access:</b></td><td>only sees what your account can see; only accepts a DAF SharePoint address.</td></tr> <!-- source: docs/engine.md "Guardrails", Site address -->
<tr><td><b>Boundary:</b></td><td>nothing leaves DoD365, except the test-round results e-mail (masked counts, sent by hand) until the test rounds end.</td></tr> <!-- source: AGENTS.md "DoD365 boundary" -->
<tr><td><b>Verifiable:</b></td><td>read the commented code as plain text before you paste it; the window warns when the script does not match its hash.</td></tr> <!-- source: engine/ps/window/05-alignment.ps1 (ScriptWarn); the README "Open as .txt" link -->
<tr><td><b>Accessible:</b></td><td>paste and run via ISE; no code download, no admin rights, no policy change.</td></tr> <!-- source: AGENTS.md "No code fetch at run time"; 90-161.Z ISSM ruling 2026-11-13 -->
<tr><td><b>Maintenance:</b></td><td>Diagnose, Back up and Restore from the application's card.</td></tr> <!-- source: docs/engine.md "Maintenance run types" -->
<tr><td><b>Independent:</b></td><td>delete RADE and the application still works.</td></tr> <!-- source: docs/engine.md "RADE and the app", After the install -->
</table>

> Need help? Ask in the Teams channel **RHOPE-OPS**.
<!-- /site:key-facts -->

---

### 🔺 Applications

<!-- >>> apps: generated from apps.json by scripts/build_readme.py --write (do not edit) -->
## 90\-161.Z

**Test round R41**

### Copy the script for 90\-161.Z.

Round R41 r1: window r14 with your test site lists (read only), every screen, an endorser answer by list form, and RADE Restore of fake rows.

`90161Z-R41-round-r1.ps1`<br>
1,404,941 bytes, 15,876 lines<br>
Script check: `1115c1f1a894...78b1`, the stored hash ([.sha256.json](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R41-round-r1.ps1.sha256.json)). The RADE window shows the same value in its title bar.

| Link | What to do |
| --- | --- |
| **[Copy script](https://github.com/rhope-ops/90-161.Z/blob/main/scripts/gov/paste/90161Z-R41-round-r1.ps1)** | Select "Copy raw file" (the copy button at the top right of the code). Then do the steps below. |
| **[Open as .txt](https://raw.githubusercontent.com/rhope-ops/90-161.Z/main/scripts/gov/paste/90161Z-R41-round-r1.ps1)** | The script as plain text, to read before you paste. Ctrl+S saves it as a .txt file; Ctrl+A, then Ctrl+C copies it. |
| **[Tasks for this application](https://github.com/rhope-ops/90-161.Z)** | The 90\-161.Z repository: its tasks and round scripts. |

If one link is blocked on your network, try the other.

1. Start menu: type ISE and open Windows PowerShell ISE as yourself (not "Run as administrator").
2. File > New. Click in the white script pane. Press Ctrl+V, then F5.
3. The RADE window opens. Do what it says.

For help, ask in the Teams channel **RHOPE-OPS**.
<!-- <<< apps -->

---

### 🔺 How it works

<kbd>Paste in ISE</kbd> → <kbd>Check the computer</kbd> → <kbd>Choose an application</kbd> → <kbd>Check what it needs</kbd> → <kbd>Install, step by step</kbd> → <kbd><b>Start</b></kbd>

#### Check results

| Result | Means |
|---|---|
| PASSED | The check passed. |
| PASSED (fallback) | Passed with the documented route for wings with less access. |
| WARNING | You can go on; read the note. |
| FAILED | The install cannot start. The window says what to fix. |
| NOT RUN | The check could not run. This also stops the install. |

#### Maintenance

| Button | Does | Asks first |
|---|---|---|
| Install / Update / Repair | Adds what is missing, keeps your data | No |
| Diagnose | Read-only checks; each finding names its fix | No |
| Back up | Saves each of the application's lists to your computer | No |
| Restore | Puts missing rows back, from the Recycle Bin or a backup | Yes: a dry run with counts, then you type the application name |
| Uninstall | Not built yet | — |

---

### 🔺 Limitations

| RADE cannot | What to do |
|---|---|
| See an install on another site | A search across sites is network reconnaissance, so RADE never does it. Ask the site owner. |
| Update an application that another account installed | Install with the same account, or ask a site owner to clear the install record. |
| Do a step that the platform does not let a script do (for example a Power Automate import) | RADE shows numbered steps; do them, then select Done or It failed. |
| Restore on a site that is not a test site | Restore runs only on the application's test sites. |
| Restore a person who is not on the site | That field stays empty; fill it in by hand. |
| Uninstall | Not built yet. Ask in the Teams channel. |

---

### 🔺 Safety

- **No reconnaissance:** never looks for hosts, pings, checks ports or probes network boundaries.
- **One host:** signs in only to an address with the DAF SharePoint prefix.
- **No code fetch at run time:** the paste is the whole program; data files are checked by SHA-256.
- **No stored credentials:** you sign in with your CAC each run; no password or token is saved.
- **No scripts in results:** the results never contain a script or program file.
- **Asks before a write that cannot be undone:** a dry run with counts, then you type the application name.
- **One install per site:** an install record on the site stops a second install by mistake.

---

### 🔺 Build an application with RADE

To deploy your own application with RADE, start with [docs/make-an-app.md](docs/make-an-app.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).
