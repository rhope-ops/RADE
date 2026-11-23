# Next prompt: RADE

Updated: 2026-11-23 by Claude (fleet v2 Stage 2 done). State, open items 0-17, older plans and what the Administrator must do: [handoff detail](reviews/2026-11-18-handoff-detail.md).

- Fleet v2 Stage 2 done (2026-11-23): engine-v36 released (#167, tag engine-v36 at 6efe5c7, 42 engine files, attestation by release.yml run 45214671013); kit 11.0.1 synced (#169); guard files (#168: security.yml bandit+gitleaks, window.yml paths, RADE_OFFLINE). Open: (1) Project rules and DECISIONS say "the Administrator" while AGENTS.md says "- Owner: the Maintainer": a rule-text change needs the Maintainer's approval of the exact lines (until then a .check code- row by "the Administrator" fails the strict gate); (2) the engine-v36 release note (upgrade: copy rade_ui.ps1 then rade_ui_text.ps1) is a hand step for the Maintainer; (3) work-computer proof: TLS 1.3 on older Windows, scripts with no -ExecutionPolicy flag, the shortcut repair.
- Plan (approved 2026-11-21): [README rework](reviews/2026-11-21-plan-readme-rework.md); done (RADE 161, 162; 90-161.Z 211); next: kit 8.0.0 sync.
- Engine: v35 R42 E1-E5 (DECISIONS 2026-11-21); v34 .txt copy; v33 mark remove; v32 local test site; v31 Restore; older: [releases](https://github.com/rhope-ops/RADE/releases). Not on a device: resume cards, CAC words, tools. Open: detail 17-25.
- Next: 90-161.Z takes engine-v35 for R42; R43: one window scale from the R42 SCALE lines (E4).
- Plan: [intro, Fulcrum](reviews/2026-11-21-plan-intro-fulcrum.md), v35+, R42.
