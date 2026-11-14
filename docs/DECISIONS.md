# Decisions: RADE

Newest first. Why the kit defaults are what they are: https://github.com/rhope-ops/archimedes_lever/blob/main/docs/DECISIONS.md. "By" = the Administrator for a decision. "By" = Agent for a recommendation that the Administrator has not approved yet.

| Date | Decision | By | Replaces |
|---|---|---|---|
| 2026-11-14 | Engine: one engine, modes deploy, test (permanent, default) and drift; base checks before Choose, app checks after; PASSED (fallback) counts as passed. Detail: docs/engine.md. | the Administrator | — |
| 2026-11-14 | Saved checks: fast checks run fresh every time; only slow checks (site rights, Power Automate look-and-answer) keep the 7-day reuse; the drift check runs all. | the Administrator | 90-161.Z DECISIONS 14 Nov (7 days for all) |
| 2026-11-14 | Drift check runs at every round's checks plus on demand; the ISSM sees the report field list before the first run. | the Administrator | — |
| 2026-11-14 | Drift check: a read-only owner app (computer, fixed hosts, own site and flows), never a network scan. Gate: key file RADE\Config\rade-owner.txt, made on the owner's computer; no DODID or its hash in the repo. Design: docs/drift-check.md. | the Administrator | — |
| 2026-11-14 | Engine work: manifest schema and a 300 KB bundle size test now; size in the summary, a hash-pinned engine (version + sha256 in the window) and a JSON results block ship in the next 90-161.Z round build after R17 (timing: agent REC, so R17 r1 does not change). | the Administrator | — |
| 2026-11-14 | Recommended settings, as rhope-ops/90-161.Z: public repo, full kit, MIT license, name guard on, time zone America/Chicago, agents say "the Administrator", project log in a private Claude doc, cloud environment RADE. | the Administrator | — |
| 2026-11-14 | Use the rhope-ops/archimedes_lever baseline instructions. | the Administrator | — |
