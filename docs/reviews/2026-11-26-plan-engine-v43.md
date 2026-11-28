# Plan: engine-v43, sign-in root cause and the logo block (2026-11-26)

Status: approved by the Administrator (the Administrator) on 2026-11-26 at about 08:20 Central (question dialog: "Approve, 4 runs"; "Test first, then R44 steps"). Source: 90-161.Z R44 r1 on the work computer, reported in chat on 2026-11-26: the CAC sign-in window showed and froze in both RADE runs (go.md steps 5 and 18); the Administrator force-closed the windows; no log came back. This session edits both repos (RADE and 90-161.Z) on the Administrator's request.

## Evidence before the plan

- R43 (engine-v41): every sign-in passed while RADE ran inside ISE (T21, T22 site read, the rights check). The one hang (Uninstall, "the signon window appeared", then no response) was in the second window: the shortcut, RADE in a separate `powershell.exe -STA -WindowStyle Minimized`.
- engine-v42 E3 moved the ISE run into that same host. In R44 r1 both runs froze at the sign-in. The child sign-in scripts did not change between R43 and R44.
- Hypothesis (confidence medium, no device data): the host process of RADE, or the sign-in size watch, freezes the PnP web login window. The test below separates the two.

## Items

1. **S1 Stage limit on every sign-in child.** The rights check, the install record, Back up and Restore children write `STAGE signin` before Connect-PnPOnline and the next STAGE after it; RADE stops a stage after 180 s and the card names it. No force close.
2. **S2 Window state.** While a child signs in, RADE reads its own child's top-level windows (count, visible, size, `IsHungAppWindow`) about every 5 s and writes one `SIGNIN-WIN` line at each change. Own process only (Project rule "No reconnaissance").
3. **S3 Host line.** Each sign-in result line names the host (`host=ise` or `host=child`) and the watch (`watch=on` or `watch=off`).
4. **L1 Logo block** (the Administrator approved the mock, 2026-11-26): row 1 is the RADE logo, "RADE", and under it "Test, deploy, enjoy" (no period) at all times; row 2 (an app with a logo is chosen) is the app logo, the app name in the RADE word style, and under it the new optional manifest field `application.subtitle` in the gray small style. Replaces part of DECISIONS 2026-11-19 (the app name no longer replaces the tagline).
5. **Release** engine-v43 by release.yml; message to 90-161.Z with the tag and the commit.

## 90-161.Z R44 r2 (that repo's plan: docs/reviews/2026-11-26-r44r2-plan.md)

The same sign-in 4 times, first in the round: A ISE + watch on, B ISE + watch off, C child + watch on, D child + watch off. Then the R44 r1 steps in the host that passed.

## Proof

- scripts/check.sh green on the head; the window job draws the logo block in both states (render for the Administrator before the merge).
- R44 r2 on the work computer: 4 SIGNIN lines with host, watch, stage and window state.
