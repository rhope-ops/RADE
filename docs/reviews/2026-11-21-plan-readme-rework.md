# Plan: README rework for RADE and 90-161.Z (approved 2026-11-21)

Approved by the Administrator on 2026-11-21, with the gaps included. Model: the 33-332.Z README (banner, name and subtitle, intro, Summary, help line, one "Open the script" link to a .txt, How it works, Limitations, Safety, Files).
Previews v3 were shown in the session chat, and the text is made again from this plan and the decisions below.

## Decisions (the Administrator, 2026-11-21; scope: this README task in RADE, 90-161.Z and the kit)

- The 90-161.Z tasks move to TASKS.md, which is still made from go.md; the README becomes the product page.
- One "Open the script" link to a .txt. The RADE engine writes a .txt next to every bundle.
- The README is the source of each site's intro and Summary; the sync code (33-332.Z scripts/build_site.py, made general) goes into the kit first.
- 90-161.Z Summary shows the design target. Built: the endorsement flows, the PFM window and the list forms. Marked Planned: draft cleanup, the review flows.
- 90-161.Z banner: its repository social preview image.
- On each site the intro and Summary go under the main card; page previews come before the build (lane C).
- This session also changes 90-161.Z under 90-161.Z's own rules (RADE "App repos" rule set aside for this task only).
- RADE: "Build an application with RADE" is one line with a link to docs/make-an-app.md.

Later decisions (the Administrator, 2026-11-21, question dialogs):
- Kit PR rhope-ops/archimedes_lever#96 merged (lane C, approved); tag v7.0.0 blocked by the session's git proxy: the owner makes it.
- README intro opens with the AGENTS.md "Purpose" line (the kit "README" default).
- Both pages use Fulcrum Minimal (the kit's docs/brand/fulcrum.css, as 33-332.Z): ink band, gold rule, cream page, ember button, the README text in an ink disc (previews v2 approved). The RADE window keeps engine/ui-tokens.json for now (open item). "Done" on the RADE page shows in Fulcrum gold.
- RADE session load over the cap after the sync: move old handoff lines into the handoff detail file.

## Steps (each needs the one before it)

| # | Repo | Work | Lane | State |
|---|---|---|---|---|
| 1 | kit | Attach the kit repo. Make build_site.py general (README marked sections into index.html; --check fails on drift). Release the kit. | C (check.sh) | done: #96 merged a15b34b; tag pending |
| 2 | RADE | rade_build.py writes a .txt next to each bundle, with tests. Release engine-v33. | B | open |
| 3 | 90-161.Z | Take engine-v33 and the kit release; rebuild the bundles; tasks to TASKS.md; new README; page preview, then the page. | B, then C | open |
| 4 | RADE | Take the kit release; the apps block links only the .txt; new README; page preview, then the page. | B, then C | open |
| 5 | all | Confirm that main has each commit; report the tags and links. | — | open |

## Gaps (included by approval)

- Summary facts get a source: each Summary row has a comment that names the file or decision that makes it true (steps 3 and 4).
- Link check: build_readme.py fails when a script link it writes points to a file that is not in the app's manifest or repo (steps 3 and 4).
- Kit first makes the work slower: step 1 must merge before steps 3 and 4.

Effort: authored by the session; one fresh reviewer per pull request (5). Estimate 4 to 6 hours.
