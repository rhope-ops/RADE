# Drift check (design, not built)

Status: design, 2026-11-14. Decisions: [DECISIONS.md](DECISIONS.md). Build: in the RADE engine, in the round after R17 (the engine still lives in rhope-ops/90-161.Z until then).

## Purpose

Find changes on the work computer, in PowerShell, SharePoint or Power Automate that can break the owner's apps, and send them back for a fix round. It is a read-only check of what the owner's own account can see. It is not a network scan: it never probes hosts or ports beyond the fixed list the apps already use.

## Gate: owner app with a local key (the Administrator, 2026-11-14)

- The catalog lists "Drift check" only when `OneDrive\RADE\Config\rade-owner.txt` exists (RADE\Config also holds rade-mail-to.txt and rade-checks.json).
- The file holds a random 32-byte key, made once by a step in an owner-only round (unticked by default). Nothing about the owner is in the repo: no DODID, no hash of it.
- The gate only prevents use by accident: the code is public and pasted, so anyone can edit their own copy. Real protection: the check reads only what the account running it can read, writes only to that user's OneDrive and drafts only to the address that user types.

## What it reads (3 layers)

| Layer | Reads | Engine checks it reuses |
|---|---|---|
| This computer | PowerShell, .NET and module versions; language mode; execution policy; AppLocker rule counts; Office and Outlook build; WebView2; fonts | ps, lang, outlook, word, pnp; T15 inventory r2 fields |
| Fixed hosts | Status only, for the hosts the apps already use | net-bookmark, net-site, net-flow |
| Own site and flows | The owner's rights on each app list, list columns, flow on/off state and connection health | site-rights, flow-guide; PnP when signed in |

## How it reports

1. Compares each value with the baseline in `RADE\Config\rade-drift-baseline.json` (written after each run).
2. Maps each change to the apps whose steps list that check in `needs` (schemas/rade-manifest.schema.json). Example: `CHANGED lang: FullLanguage -> ConstrainedLanguage; affects 90-161.Z, SPAR`.
3. Writes a masked report (counts, versions, pass/fail; no computer name, user name, paths, site address or DODID) and an Outlook draft, never sent. Subject: `RADE DRIFT <yyyy-mm-dd> NEEDS REVIEW` or `... NO CHANGE`.

## Trust on the way back

- The owner sends the draft. Agents act only on result e-mails from the owner's work address (90-161.Z AGENTS.md "Result e-mails"). Only rhope-ops can commit the fix, and the owner runs the fix round.
- The key is never in a report or e-mail. A forged e-mail can at worst make an agent prepare a fix round that the owner must still run.

## Not in scope

Network or port scanning; scheduled runs (Task Scheduler on a locked device looks like persistence and needs its own approval); automatic sending.

## When and approval (the Administrator, 2026-11-14)

- Drift is compared at every round's checks, plus "Drift check" on demand (engine.md "Check stages").
- The ISSM sees the report field list once before the first run; the first run waits for the ISSM's OK.
