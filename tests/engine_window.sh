#!/usr/bin/env bash
# RADE engine tests, the window part: sourced by tests/engine_test.sh (its section "window"), never run alone. Split out
# of engine_test.sh by the speed audit of 2026-11-17 (docs/code-standard.md C4: a file is at most 600 lines). Uses what
# engine_test.sh defined before it: $t, $b, $engine_src, swap, ans, go, ok and bad. Starts the background groups W, W2, W3 and W4;
# engine_test.sh "gather" waits for them and adds their counts.
# Network: none.
# Writes: temporary files under the test folder $t, deleted on exit.
# Credentials: none.

# ---- window: the "One thing" window (docs/window-design.md) with stand-in Windows Forms types (tests/window_stub.cs) and
# a scripted user (tests/window_driver.ps1) that prints one WIN line per card, runs every Paint handler and checks names.
# wgo DIR [seed]: a window group's own folder $t/DIR ($wd): its users root, its bundle copies and its win.txt. The window
# runs are 3 groups (W, W2, W3) that run at once: one chain of 12 runs took about 75 s (speed audit, 2026-11-17). W2 and W3
# start from a copy of the users root as window run 1 (the first deploy) left it ($t/wseed, made by W): an installed app.
wgo() { wd="$t/$1"; mkdir -p "$wd/u/test1234/OneDrive - United States Air Force"; swap "$b" "$wd/wb.ps1" "$wd/u"
  if [ -n "${2:-}" ]; then local n=0; until [ -e "$t/wseed.done" ] || [ $((n += 1)) -gt 1500 ]; do sleep 0.2; done
    # at most 300 s: if group W ended early and left no seed, the group goes on without it and its checks fail
    if [ -e "$t/wseed.done" ]; then cp -a "$t/wseed/." "$wd/u/"; else echo "  no seed from group W after 300 s ($t/wseed.done)"; fi; fi; }
# stub: the stand-in types for win, as the DLL that group W compiles once before its first run ($t/window_stub.dll), or
# the C# source when there is no DLL (each run then compiles it: about 0.8 s of CPU more for each of the 12 runs).
stub() { if [ -s "$t/window_stub.dll" ]; then echo "$t/window_stub.dll"; else echo "$PWD/tests/window_stub.cs"; fi; }
# win APP HAND RECORD TOUR [BUNDLE]: runs the window for application APP (0 = test, 1 = deploy); output in $wd/win.txt.
win() { sed -E -e 's#Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing#$null = 0#' -e "s#^\\\$sitePrefix = 'https://usaf.dps.mil/sites/'#\$sitePrefix = 'https://rade-test.invalid/sites/'#" -e 's#System\.Drawing\.(FontStyle|Font|Pen|SolidBrush|Image|Graphics)\b#RadeDraw.\1#g' "${5:-$wd/wb.ps1}" > "$wd/wb2.ps1"
  cat tests/window_driver.ps1 "$wd/wb2.ps1" > "$wd/w.ps1"
  RADE_T_FAULT="${fault:-}" RADE_T_CANCEL="${cancel:-}" RADE_T_START="${start:-}" RADE_T_LINK="${link:-}" RADE_T_SCALE="${scale:-}" RADE_T_LOOP="${loop:-}" RADE_T_FEEDBACK="${feedback:-}" RADE_T_WALK="${walk:-}" RADE_T_STUB="$(stub)" RADE_T_APP="$1" RADE_T_HAND="$2" RADE_T_RECORD="$3" RADE_T_TOUR="$4" USERPROFILE="$wd/u/test1234" timeout 180 pwsh -NoProfile -File "$wd/w.ps1" < /dev/null > "$wd/win.txt" 2>&1; }
# has TEXT...: every text is in the window output, and the window did not fall back to text mode or miss a name.
has() { local x; grep -q "No window could open\|WIN NONAME\|WIN NOFOCUS\|WIN BAD" "$wd/win.txt" && { grep -m3 "No window could open\|WIN NONAME\|WIN NOFOCUS\|WIN BAD" "$wd/win.txt" | cut -c1-300; return 1; }; for x in "$@"; do grep -qF -- "$x" "$wd/win.txt" || { echo "  missing: $x"; return 1; }; done; grep -q "^WIN closed=True" "$wd/win.txt"; }
go W; {   # group W: runs in the background (see "go" in tests/engine_test.sh)
wgo w1
RADE_T_STUB="$PWD/tests/window_stub.cs" RADE_T_STUB_OUT="$t/window_stub.dll" pwsh -NoProfile -File tests/window_driver.ps1 > "$t/stub.txt" 2>&1 || cat "$t/stub.txt"
# 1. A first deploy: boot, choose with the newer-version notice, ready, the Record (boxes can change, Clean-up off), the hand step, done.
win 1 done 1 0; cp -a "$wd/u" "$t/wseed"; : > "$t/wseed.done"   # the seed of W2 and W3 (wgo)
has "view=boot" "view=choose light=off kick= sent=Which application do you want to install?" "2 Sample app (deploy) 1.0.0 NOTE Version 9.0.0 is on the RADE page" "view=ready light=off kick=ALL 8 CHECKS PASSED sent=Ready to install Sample app (deploy) 1.0.0." \
  "WIN record on=True rows=10 boxes=5 enabled=True text=True name=True reused=Last check: 14 Nov 26 / Version [5.1] tall=True" "WIN record-copy btn=Copied checks=True detail=True steps=True text=True name=True" "WIN paged=" "WIN record on=False clean=False" "view=hand light=your turn kick=STEP 2 OF 3 sent=Import the sample flow" "btn=[It failed] [Skip] [Imported]" \
  "view=done light=off kick=ALL STEPS PASSED sent=Sample app (deploy) 1.0.0 is installed. p=Nothing was sent." "btn=[Close] [Open results folder] [Copy summary] [Start Sample app (deploy)]" "WIN made=True log=True locked=True" "WIN copied=True" && ! grep -q "foot=Site\|Change the site address" "$wd/win.txt" && ok || { bad "window 1: first deploy"; tail -5 "$wd/win.txt" | cut -c1-300; }
# 1a. The polish pass of 17 Nov (docs/window-design.md "Type", "Cards"): the manifest title is what the window shows (the hand card's
# headline, the step line of a run, the Record's step boxes and their accessible names, the foot of the Run card), a step with no title shows
# its name, and the report keeps the name; the hand card shows the step note under the headline, then the address row, then the numbered
# lines (a line without a number goes after the list, small and gray), then the one closing line (with the step's doneText), above the
# buttons; one typeface in 5 styles ($ui.F has only those tokens; every button has the strong font, also a plain one; Consolas is only the
# Record's text box); the last log line is small.
has "view=hand light=your turn kick=STEP 2 OF 3 sent=Import the sample flow p=You do this step in the browser. RADE cannot do it for you. steps=1. Open the import page. ~ 2. Choose the file on the clipboard. ~ 3. Select Import. rest=RADE cannot see the import page, so it asks you to confirm. close=When you finish in the browser, come back to this window and select \"Imported\"." \
  "step=Check this computer now-font=Segoe UI10" "step=T03 Sample verify r1" 'foot=RADE needs you next at "Import the sample flow". Until then, keep this window open.' \
  "box-text=Clean-up|1  Check this computer|2  T04 Sample optional r1|3  Import the sample flow  (needs you)|4  T03 Sample verify r1 box-name=1  Check this computer" \
  "WIN hand-order address-above-lines=True lines-above-path=True path-above-links=True closing-above-buttons=True closing-gap=4" "WIN F tokens=Body,Link,Mono,Sent,Small,SmallB,Turn,Word mono-only-in-record=True sent=Segoe UI Semibold22 body=Segoe UI12 small=10 smallb=Segoe UI Semibold10 help=12 kick=Segoe UI Semibold label=Segoe UI Semibold plainbtn=Segoe UI Semibold link=Segoe UI Semibold now=Segoe UI" && ok || { bad "window 1a: titles, hand card order, type styles"; grep "view=hand\|step=\|box-text\|WIN F\|hand-order\|BAD" "$wd/win.txt" | cut -c1-700; }
# 1a2. R28 fixes (rhope-ops/90-161.Z round R28, the PFM's notes): N4 the lines of a hand step are ONE selectable rich text (numbers in a
# right-aligned column by a right tab, text in a hanging indent); copying across lines gives the lines as written (no tabs) and a path that
# RADE broke to fit copies whole; N1 a step with no address has no address row, a closing line without "browser", and the focus on its text
# (Enter answers nothing); N6 the hand card shows the file's full path; N10 the step line has the time in the step ("4m 12s"); N8 the install
# card of a deploy asks for the folder of the RADE shortcut; the Done card of a first install has Start (it was missing in R28).
has "WIN guide one-box=True rtf=True selectable=True" "WIN guide-copy=1. Open the import page.|2. Choose path-copy=C:\\ab.zip" "WIN elapsed=4m 12s|0m 05s|1h 02m 05s" \
  'WIN no-address field=False close=When you finish, select "Imported". focus-text=True accept=False' "/RADE/SampleApp/T02/SAMPLE-T02-import-r1.zip" "time=0m 0" \
  "view=ready light=off kick=ALL 8 CHECKS PASSED" "field=RADE shortcut in:" && ok || { bad "window 1a2: R28 fixes on the hand, run and ready cards"; grep "WIN guide\|WIN elapsed\|no-address\|path=\|time=\|field=" "$wd/win.txt" | cut -c1-300; }
# 1a3. R35 (the Administrator, 2026-11-19): "Your turn" in bold, in the accent color, on its own line right above the headline (the
# header row: the line in capitals, then it), only on a card where RADE waits for the person (the yellow light), and its line keeps its
# room when it is empty; the line in capitals has no "your turn". No changing value moves or resizes a control: on the Run card (every
# step title, the time to about 10 hours, the count to "999 of 999", the percent, the now-doing line) and the checking card (each check
# name and its count), and the probe (a title outside the card's range) shows that the test sees a change. (A long WIN line that the
# console wrapped is not read for "turn=".)
has "WIN turn font=Segoe UI Semibold 12 Regular blue=True head=Kick,Turn down=TopDown same-h=True shown=True" "WIN steady run values=23 moved=0 probe=True" "WIN steady checking values=" &&
  grep "^WIN steady checking " "$wd/win.txt" | grep -q " moved=0 probe=True" && ! grep -qi "kick=[^=]*your turn" "$wd/win.txt" &&
  [ "$(grep "^WIN view=.* help=[TF][a-z]* turn=" "$wd/win.txt" | awk '{ y = ($0 ~ / light=your turn /); u = ($0 ~ / turn=Your turn$/); s = ($0 ~ / turn=(hidden)?$/); if (y != u || (!y && !s)) n++ } END { print n + 0 }')" = 0 ] &&
  grep -q "^WIN view=hand .* turn=Your turn$" "$wd/win.txt" && grep -q "^WIN view=run .* turn=$" "$wd/win.txt" && ok || { bad "window 1a3: Your turn above the headline, no value moves a control"; grep "WIN turn\|WIN steady" "$wd/win.txt" | cut -c1-400; }
[ "$(cat $engine_src engine/rade_ui.ps1 | grep -c Consolas)" = 1 ] && grep -qF "mono = @('Consolas', '', 'Consolas')" engine/rade_ui.ps1 && grep -qF "\$ui.Styles.Mono = @('mono', 9, '')" engine/rade_ui.ps1 && [ "$(cat $engine_src engine/rade_ui.ps1 | grep -c 'F\.Mono')" = 1 ] && grep -q "RecText.Font = \$ui.F.Mono" $engine_src && ok || bad "type: Consolas is only the Mono token, and only the Record's text box uses it"
wr="$wd/u/test1234/OneDrive - United States Air Force/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"
! grep -q "Import the sample flow\|Check this computer" "$wr" && grep -q "^T01 Sample check r1: PASSED" "$wr" && grep -q "^T02 Sample import r1: PASSED (confirmed by you)" "$wr" && ok || { bad "title: the report keeps the step name and never shows the title"; grep -n "Import the sample flow\|Check this computer" "$wr"; }
# 1b. The hand step's questions after Done: one card each (No, the second choice, a text with an e-mail address), and
# their lines under the step's line in the report, the text masked (docs/engine.md "Step contract").
wr="$wd/u/test1234/OneDrive - United States Air Force/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"
has "view=answer light=your turn kick=STEP 2 OF 3 · QUESTION 1 OF 3 sent=Did the flow run start? p= btn=[Yes] [No]" "kick=STEP 2 OF 3 · QUESTION 2 OF 3 sent=How many flows does the import page show? p= btn=[One] [Two] [Three or more]" \
  "kick=STEP 2 OF 3 · QUESTION 3 OF 3 sent=Anything else to report? p=Do not type names or addresses. btn=[Continue]" "WIN answer-box max=10000 enter=Continue focus=True" && [ "$(grep -c "^WIN view=answer" "$wd/win.txt")" = 3 ] &&
  [ "$(grep -A3 "^T02 Sample import r1: PASSED (confirmed by you) in " "$wr" | tail -3 | tr -d '\r' | tr '\n' '|')" = "  Answer run-started: No|  Answer flow-count: Two|  Answer note: Mail <EMAIL> about it|" ] && ! grep -q "someone@" "$wr" && ok || { bad "window 1b: the answer cards and the answers in the report"; grep -A3 "^T02 Sample" "$wr"; grep "view=answer\|answer-box" "$wd/win.txt" | cut -c1-300; }
# 1b2. After a deploy that passed (R28): RADE keeps a copy of the pasted text as the installed runner, and says in plain words what it did about the
# desktop shortcut (here no Desktop folder exists, so it says it made none; the .lnk itself is made with WScript.Shell on Windows only).
rn="$wd/u/test1234/OneDrive - United States Air Force/RADE/rade-runner.ps1"
[ -f "$rn" ] && grep -q "^\$buildId = '" "$rn" && grep -q "^\$engineRelease = [0-9]" "$rn" && grep -qF "RADE could not find your Desktop folder, so it made no desktop shortcut. Open RADE from the RADE page instead." "$wd/win.txt" && ok || bad "window 1b2: installed runner copy and the desktop shortcut line"
# 1c. A minimized window comes back when RADE needs the person; it has its own taskbar button (Application.Run: no owner).
# The layout line and the SCALE line at 100 %; the sizes RADE sets after the form has scaled, at 100 % (the same numbers as
# before the one scale source: tests/window_driver.ps1 "WIN measure").
has "WIN restored=Normal taskbar=True minbox=True shown-by=Run" "WIN layline=Layout self-check: PASS layout, 0 cards (1216 x 684 at 100 %) ~ SCALE dpiX=96 deviceDpi=n/a mode=Dpi asd=96x96 autoScale=96x96 font=17 fontPt=10 fontScale=1 ctlScale=1 realDpi=n/a aware=n/a screen=1280x800 work=1280x720 client=1216x684 state=Normal logo=64x64 btn=160x40" \
  "WIN measure choice h=110 gap=8 plan-x=54" "WIN measure record box=5,4 label=5,6 rows=451" && ok || { bad "window 1c: restore, taskbar, the scale line"; grep "restored=\|layline=\|WIN measure record" "$wd/win.txt" | cut -c1-300; }
# 1d. Polish after the R24 pictures (docs/window-design.md "Sizes"): the header and the label-box-button rows share one
# midpoint within 1 px (from margins and sizes; an odd height gives a half pixel; the stand-ins have no layout), a box is as tall as a compact button, gaps of 8; the
# question headline is the prompt's first sentence (one sentence: no body line; two: the rest is the body line, 1b) and a
# first sentence too long for one line shrinks (22 pt, floor 13.2 pt = 60 %; the stand-ins' card is 258 px); the self-check's alignment rules pass an aligned fixture
# and give one LAYOUT line for each fault of a misaligned one (a box 6.5 px off, a button 3 px off, box 23 vs button 30, a headline 3 px right).
# R29b: the word RADE is in the title column, centered on the logo, and both header lines start their ink on one edge (stand-in ink:
# the 1/6 em estimate, 4 and 3 px, so the name moves 1 px); the step's time and count sit on the bar's midpoint at 100, 150 and 200 % (the
# bar moves down when the text is taller than its place, by the same 13 px on a second fit); the header rule fails on any edge difference,
# the ticker rule on more than 1 px. R31 (docs/reviews/2026-11-19-r31-plan.md): the rules of the header line (L2: 4 px, the line, 4 px, ink to ink),
# of a label above its box (L3: the text answer's box is under its label, on the card's edge, as wide as the text) and of the card frame (L1).
has "WIN mid hand label=18.5 box=19 button=19 box-h=30 button-h=30 gaps=8,8 inner=148/160 tick=0" "WIN mid header logo=32 title=32 word-in-title=True ink-left=4,4" "WIN mid tick base=11 100%:0.5/0.5 150%:0/0 200%:0/0 lift=13 again=0 off=0.5" "WIN mid approw shown=True link=True applogo=32 app=31.5 name=Sample app (deploy) 1.0.0 logoname=Sample app (deploy) logo" "WIN mid answer above=True box-top=4 box-left=10 box-w=-10 h=30" \
  'WIN sent-pt=22 for "Did the flow run start?"' 'WIN sent-pt=22 for "Anything else to report?"' 'WIN sent-pt=13.2 for "How many flows does the import page show?"' \
  "WIN rule head=1 tick-ok=0 tick-off=3 ~ LAYOUT fixture header AppL edge: starts at 80, WordL starts at 86 ~ LAYOUT fixture StepRow StepTime midpoint: 14.5, the bar midpoint is 13 ~ LAYOUT fixture StepRow StepTime midpoint: 22, the bar midpoint is 19 ~ LAYOUT fixture StepRow StepTime midpoint: 24, the bar midpoint is 26" \
  "WIN rule r31 head-ok=0 head-off=4 above-ok=0 above-off=3 frame-ok=0 frame-off=2 ~ LAYOUT fixture header gap: 7 between the word RADE and the line, the gap is 4 ~ LAYOUT fixture header gap: 7 between the line and the application name, the gap is 4 ~ LAYOUT fixture header line: 47 wide, the word RADE is 52 ~ LAYOUT fixture header line: starts at 83, the word RADE starts at 80 ~ LAYOUT fixture FieldRow label: its bottom is at 40, the box starts at 22 ~ LAYOUT fixture FieldBox edge: starts at 137, the card edge is 125 ~ LAYOUT fixture FieldBox width: 390, the card text is 590 wide ~ LAYOUT fixture frame: the header row is at 126, the fixed top is 96 ~ LAYOUT fixture frame: 320 high, the minimum is 360" \
  "WIN rule aligned=0 misaligned=4 ~ LAYOUT fixture FieldRow FieldBox midpoint: 15.5, the row midpoint is 22 ~ LAYOUT fixture FieldRow FieldB midpoint: 19, the row midpoint is 22 ~ LAYOUT fixture FieldRow heights: box FieldBox 23, button FieldB 30 ~ LAYOUT fixture Sent edge: starts at 126, the card edge is 123 (Kick)" && ok || { bad "window 1d: alignment, question headline, alignment rules"; grep "WIN mid\|sent-pt\|WIN rule" "$wd/win.txt" | cut -c1-300; }
# 1f. Review of b093036: a click within 400 ms of a new card does nothing (a double-click on Done answers no question
# unseen; Enter clicks the same buttons); a word wider than the line is cut into pieces that fit, and the self-check
# reports a word of a wrapping label that is wider than the label; the Record's step boxes are one line that ends with
# "..." (R24 job: "(needs you)" was cut to "(ne"), shortened by RADE (no AutoEllipsis: no tooltip); the click guard runs on a
# monotonic clock (a reference "in the future", as after the clock stepped back, never blocks; 401 ms after a card the click
# is taken, 100 ms after it is not); long words break by text element (a surrogate pair stays whole) and in body lines too.
has "WIN measure record box=5,4 label=5,6 rows=451 one-line=True" "WIN guard held=True then=Yes" "WIN break=abc|def|ghi|j word-bad=LAYOUT fixture P0 text: the word \"abcdefghij\" needs 70, the line is 50 word-ok=True" && ok || { bad "window 1f: click guard, long words"; grep "WIN guard\|WIN break" "$wd/win.txt" | cut -c1-300; }
# 1g. Second review of 9d71b28: the click guard on a monotonic clock, breaks by text element and in body lines, and a step
# name shortened by RADE with "..." (no AutoEllipsis).
has "WIN clock future=True after400=True within=False" && ok || { bad "window 1g: monotonic click guard"; grep "WIN clock" "$wd/win.txt"; }
has "WIN surrogate pieces=3 whole=True" "WIN shorten=abcd... body-break=True" && ok || { bad "window 1g: text elements, body lines, shortened step names"; grep "WIN surrogate\|WIN shorten" "$wd/win.txt"; }
# 1e. R24 job on b093036: a box's text box fills its frame (frame - 2 x 6) also when the frame's size never changed, and the
# box is as tall as the compact button measured; a row that wraps is aligned line by line (the check box alone on the
# second line of the test extras is no defect; on the first line, 39 px low, it is).
has "WIN rule wrapped=0 one-line=1 ~ LAYOUT fixture TestRow OkBox midpoint: 58, the row midpoint is 19" && ok || { bad "window 1e: rows that wrap"; grep "WIN rule" "$wd/win.txt" | cut -c1-300; }
# 2. A second deploy with a blocked application, Maintenance (Esc = Back, then the same choice: 2 Maintenance cards),
# the site address, a failed check that runs again (2 cards), a sign-in check that failed (its card offers the sign-in),
# the look-and-answer check, and a hand step that failed: needs review with the help line.
win 1 fail 0 1
has "opts=OFF Sample app; 1 Sample app (deploy) 1.0.0" "btn=[Check this computer again]" "view=maint light=off kick=SAMPLE APP (DEPLOY) 1.0.0 · INSTALLED " "sent=Maintenance" "p=Repair adds what is missing and keeps your data. / Start runs the checks, then opens Sample app (deploy)." "btn=[Repair] (Uninstall) [Start Sample app (deploy)]" \
  "view=site light=off kick= sent=Which site does the application go to?" "WIN site-note=The address must look like https://rade-test.invalid/sites/name" "view=fail light=failed kick=CHECK 9 OF 11 · FAILED sent=One check failed. p=Your SharePoint site can be reached" "btn=[Change the site address] [Run checks again]" "WIN esc" "WIN again" "sent=One check failed. p=You can change the site (sign in with your CAC) / Sign-in was not finished" "btn=[Change the site address] [Sign in and check site rights]" \
  "view=need light=your turn kick=CHECK 10 OF 11 sent=One check needs you." "btn=[Sign in and check site rights]" "btn=[Check Power Automate]" "sent=Check Power Automate" "btn=[No: one is missing] [Not now] [Yes: I see both]" "steps=1. Select Open in browser. Power Automate opens; sign in with your CAC if asked. ~ 2. Look at the left menu" "rest=You look in Power Automate and answer (about 2 minutes, an estimate). Nothing is changed. close=When you finish in the browser, come back to this window and select \"Yes: I see both\"." "kick=ALL 11 CHECKS PASSED" "btn=[Install] [Change the site address] [Start Sample app (deploy)] foot=Site: fake" "WIN start-button=Start Sample app (deploy) main=Start Sample app (deploy)" \
  "view=handfail" "view=review light=failed kick=NEEDS REVIEW sent=The install is not complete. p=T02 Sample import r1: FAILED (reported by you)" "flow <SITE> not found" "help=For help, ask in the Teams channel" "btn=[Open results folder] [Close] [Copy summary]" && [ "$(grep -c "^WIN view=maint" "$wd/win.txt")" = 2 ] && [ "$(grep -c "^WIN view=fail .*CHECK 9 OF 11" "$wd/win.txt")" = 2 ] && ! grep -q "^WIN view=answer" "$wd/win.txt" && ok || { bad "window 2: Maintenance, checks that fail or need you, needs review (and no question after It failed)"; grep "view=maint\|view=ready" "$wd/win.txt" | cut -c1-900; tail -5 "$wd/win.txt" | cut -c1-300; }
# 2b. Start (R28): the installed application has the Start button; selecting it runs the start script of the local copy in its own
# powershell.exe process and closes RADE. A test application (no start script) has none.
start=1 win 1 done 0 0
has "WIN start-button=Start Sample app (deploy) main=Start Sample app (deploy)" "WIN start-process powershell.exe" "WIN started=True closed=True" && ok || { bad "window 2b: Start"; grep "start" "$wd/win.txt" | cut -c1-200; }
# 2b2. Start on Maintenance (R28 fix): it runs the checks, then starts the application (no Ready card click), and RADE closes.
start=maint win 1 done 0 0
has "view=maint" "btn=[Repair] (Uninstall) [Start Sample app (deploy)]" "view=ready " "WIN start-process powershell.exe" "WIN maint-start started=True closed=True" && ok || { bad "window 2b2: Start on Maintenance"; grep "maint\|start\|view=ready" "$wd/win.txt" | cut -c1-200; }
# 2c. Cancel on the checking card (in group W: it runs on the install state that 1 to 2b2 left, as before the split).
cancel=1 win 1 done 0 0
has "WIN cancel busy=" "view=checking light=off kick= sent=Checking this computer and your access." "btn=[Cancel]" "view=run " && [ "$(grep -c "^WIN view=choose" "$wd/win.txt")" -ge 2 ] && ok || { bad "window 2c: Cancel on the checking card"; grep "WIN cancel\|view=checking\|view=choose" "$wd/win.txt" | cut -c1-200; }
echo "GROUP $pass $fail"; } > "$t/grp-W.log" 2>&1 &
go W2; {   # group W2: runs in the background (see "go" in tests/engine_test.sh)
wgo w2 seed
# 2c. States (R28): a boot error, a paste with no application and Cancel on the checking card each have a card (and the run card has Cancel).
fault=boot win 0 done 0 0
has "view=boot" "view=booterr light=failed kick=STOPPED sent=RADE could not check this computer. p=The test made the boot checks fail / Nothing was changed. / What to do: select \"Try again\"." "btn=[Close] [Try again]" "help=For help, ask in the Teams channel" "view=choose" && ok || { bad "window 2c: boot error card"; grep "view=booterr" "$wd/win.txt" | cut -c1-300; }
fault=noapps win 0 done 0 0
has "view=noapps light=failed kick=NOTHING TO CHOOSE sent=No application is listed in this paste." "btn=[Close]" && ok || { bad "window 2c: no application card"; grep "view=noapps" "$wd/win.txt" | cut -c1-300; }
# 3. A test round: the owner's test extras show on Done; a deploy never shows them (1 and 2 have no "test=shown").
# Here Application.Run fails as when a message loop already runs on the thread: the window opens with ShowDialog.
loop=1 win 0 done 0 0
has "shown-by=ShowDialog" "sent=Ready to run round R01." "view=done light=off kick=ALL STEPS PASSED sent=Round R01 is done." "test=shown" "WIN draft-note=The Outlook draft could not be created" && ! grep -q "Sample app (deploy).*test=shown" "$wd/win.txt" && ok || { bad "window 3: test round"; tail -5 "$wd/win.txt" | cut -c1-300; }
# 4. A deploy whose download fails: stopped, with the help line.
sed "s#file://$t/app/flow/SAMPLE-data#file://$t/app/flow/NOPE#" "$wd/wb.ps1" > "$wd/wf.ps1"
win 1 done 0 0 "$wd/wf.ps1"
has "view=stopped light=failed kick=STOPPED sent=The install stopped. p=A file this install needs could not be downloaded" "help=For help, ask in the Teams channel" "btn=[Try again] [Close] [Copy the log]" && ok || { bad "window 4: stopped"; tail -5 "$wd/win.txt" | cut -c1-300; }
echo "GROUP $pass $fail"; } > "$t/grp-W2.log" 2>&1 &
go W3; {   # group W3: runs in the background (see "go" in tests/engine_test.sh)
wgo w3 seed
# 5. The R24 device case: the form scales 1.5 x (144 dpi) while the screen dpi says 96. What RADE sizes after the form has
# scaled follows the form: a drawn part (the text start of a choice: 54 -> 81), a control made later (the gap under a
# choice: 8 -> 12; the Record's step box and label margins: 5,4 -> 8,6 and 5,6 -> 8,9). The stand-ins have no layout and
# no fonts: text heights, the logo and the buttons made before the form scaled stay at their coded sizes here, and the
# layout self-check does not run (the Windows job and a round on a work computer measure those). R29b: the step bar's base margin
# follows the form too (11 -> 16).
mkdir -p "$t/lnk"; link="$t/lnk" scale=150 win 1 done 1 0
has "WIN measure choice h=120 gap=12 plan-x=81" "WIN measure record box=8,6 label=8,9 " "(1280 x 720 at 150 % (the form auto-scale; the screen dpi says 100 %)) ~ SCALE dpiX=96 deviceDpi=n/a mode=Dpi asd=96x96 autoScale=144x144 " "fontPt=15 fontScale=1.5 ctlScale=1.5 " "WIN mid tick base=16 " && ok || { bad "window 5: scale 150 % with a 96 dpi screen"; grep "measure\|layline" "$wd/win.txt" | cut -c1-300; }
# 5b. N8 (R28): a shortcut folder that does not exist keeps the Ready card with a note; the chosen folder is saved in RADE\Config (no shortcut
# is made here: WScript.Shell is Windows only, so the Done card says it could not make one).
grep -qF "WIN link-bad view=ready note=That folder was not found." "$wd/win.txt" && [ "$(head -1 "$wd/u/test1234/OneDrive - United States Air Force/RADE/Config/rade-shortcut.txt" | tr -d '\r')" = "$t/lnk" ] && grep -qF "RADE could not make a desktop shortcut." "$wd/win.txt" && ok || { bad "window 5b: the shortcut folder"; grep "link-bad\|shortcut" "$wd/win.txt" | cut -c1-300; }
# 6. Window size and place (R28): the place is saved at close; bounds off every screen are ignored (first run: maximized, the screen with the
# mouse); saved bounds are used and keep their size and state. The file holds numbers and two words only.
wp="$wd/u/test1234/OneDrive - United States Air Force/RADE/Config/rade-window.json"
[ -f "$wp" ] && grep -q '"closed"' "$wp" && ! grep -qi 'test1234\|http' "$wp" && ok || bad "window place: the file is written at close, numbers only"
printf '{"x":9000,"y":9000,"w":800,"h":600,"state":"Normal","dpi":96}' > "$wp"; win 1 done 1 0
has "placed=first run" "lastClose=" && ok || bad "window place: bounds off every screen are ignored"
printf '{"x":50,"y":40,"w":1100,"h":650,"state":"Normal","dpi":96}' > "$wp"; win 1 done 1 0
has "placed=saved" "shown=1100x650/Normal" && grep -q '"w": 1100' "$wp" && ok || bad "window place: saved bounds are used and saved again"

echo "GROUP $pass $fail"; } > "$t/grp-W3.log" 2>&1 &

go W4; {   # group W4: runs in the background (see "go" in tests/engine_test.sh)
wgo w4
# 7. The R31 brief (docs/reviews/2026-11-19-r31-plan.md; fake data): its own bundle, the sample with: T01 "doing"; the hand step T02
# without Skip ("hide") and its text question only after "Yes" ("showIf"); a step T05 that shows only questions ("answersOnly"), with an
# answer that means a failure ("failOn") and a question after the other answer. No application logo: the name is under the word RADE.
mkdir -p "$t/r31/app/scripts"; cp -r tests/fixture-app/. "$t/r31/app/"; cp schemas/examples/sample-manifest.json "$t/r31/app/scripts/paste_bundles.json"; ans "$t/r31/app/scripts/paste_bundles.json"
python3 - "$t/r31/app/scripts/paste_bundles.json" <<'P'
import json, sys
p = sys.argv[1]; m = json.load(open(p)); b = m['bundles'][0]
for s in b['steps']:
    if s['name'].startswith('T01 '): s['doing'] = 'Checking the sample files.'
    if s['name'].startswith('T02 '): s['hide'] = ['skip']; s['answers'][2]['showIf'] = {'key': 'run-started', 'in': ['Yes']}
b['steps'].append({'name': 'T05 Sample questions r1', 'dir': 'T05', 'file': '', 'kind': 'guide', 'guide': [], 'answersOnly': True, 'answers': [
    {'key': 'page', 'prompt': 'What does the page show?', 'kind': 'pick', 'choices': ['The list', 'An error'], 'failOn': ['An error']},
    {'key': 'more', 'prompt': 'Does the list show two rows?', 'kind': 'yesno', 'showIf': {'key': 'page', 'in': ['The list']}}]})
b['apps'][0]['steps'].append('T05 Sample questions r1')
json.dump(m, open(p, 'w'), indent=2)
P
python3 scripts/check_manifest.py "$t/r31/app/scripts/paste_bundles.json" > "$t/r31/check.txt" 2>&1 && python3 engine/rade_build.py --app-root "$t/r31/app" > "$t/r31/build.txt" 2>&1 && swap "$t/r31/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$wd/r31.ps1" "$wd/u" && ok || { bad "r31: the bundle with hide, answersOnly, failOn, showIf and doing is valid and builds"; tail -3 "$t/r31/check.txt" "$t/r31/build.txt"; }
walk=1 feedback='The second card was slow. Mail someone@example.com' win 0 done 0 0 "$wd/r31.ps1"
wr="$wd/u/test1234/OneDrive - United States Air Force/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"
# E1: the hand card has Done and It failed, no Skip. E3: the text question is not asked after "No", and the report says so.
has "view=hand light=your turn kick=STEP 3 OF 4 sent=" 'btn=[It failed] [Imported] back=' && ! grep -q "^WIN view=hand .*\[Skip\]" "$wd/win.txt" && [ "$(grep -c "^WIN view=answer .*STEP 3 OF 4" "$wd/win.txt")" = 2 ] &&
  [ "$(grep -A3 "^T02 Sample import r1: PASSED (confirmed by you) in " "$wr" | tail -3 | tr -d '\r' | tr '\n' '|')" = "  Answer run-started: No|  Answer flow-count: Two|  Answer note: not asked|" ] && ok || { bad "r31 E1, E3: a hidden button and a question that depends on an answer"; grep "^WIN view=hand\|^WIN view=answer" "$wd/win.txt" | cut -c1-260; grep -A3 "^T02" "$wr"; }
# E2: the step with only questions shows no hand card; its marked answer asks for the error text, the step is FAILED (reported by you)
# with the answer and the masked text, the question after the other answer is not asked, and the round needs review.
has "view=answer light=your turn kick=STEP 4 OF 4 · QUESTION 1 OF 2 sent=What does the page show? p= btn=[The list] [An error]" "view=answerfail light=your turn kick=STEP 4 OF 4 · IT FAILED sent=What did the error say?" "btn=[Continue]" "view=review light=failed" &&
  [ "$(grep -c "^WIN view=hand " "$wd/win.txt")" = 1 ] && grep -q "^T05 Sample questions r1: FAILED (reported by you) in .*: answer page: An error. Error text: The page said: error 42 at <SITE>" "$wr" &&
  [ "$(grep -A2 "^T05 Sample questions r1: FAILED" "$wr" | tail -2 | tr -d '\r' | tr '\n' '|')" = "  Answer page: An error|  Answer more: not asked|" ] && head -1 "$wr" | grep -q "NEEDS REVIEW" && ok || { bad "r31 E2: a step with only questions, and an answer that means a failure"; grep "^WIN view=answer\|^T05\|Answer" "$wd/win.txt" "$wr" | cut -c1-260; }
# The top bar and the state text (the Administrator, 2026-11-19): the title is the full name, the build and nothing else (no round, no
# tagline); at the first frame the tagline stands in the name's spot, shown, in the name's font; the bottom right has the percent only.
grep -q "^WIN script-warn mismatch view=choose text=\[This script does not match its hash. Do not run it.\] red=True$" "$wd/win.txt" && grep -q "^WIN script-warn match view=choose text=\[\] red=False$" "$wd/win.txt" && grep -q "^WIN script-warn unavailable view=choose text=\[\] red=False$" "$wd/win.txt" &&
  ( for v in choose ready boot; do grep -q "^WIN script-warn own mismatch $v text=\[This script does not match its hash. Do not run it.\] red=True$" "$wd/win.txt" || exit 1; done ) &&
  grep -q "^WIN script-warn own match choose text=\[Last round on this computer: none recorded yet.\] red=False$" "$wd/win.txt" &&
  grep -q "^WIN script-warn own match ready text=\[Site: example\] red=False$" "$wd/win.txt" &&
  grep -q "^WIN script-warn own match boot text=\[\] red=False$" "$wd/win.txt" && ok || bad "script hash warning: red line on a mismatch, none on a match or when not available"
grep -q "^WIN topbar title=Redacted Application Deployment Engine · build [^ ]* spot=Test, deploy, enjoy\. shown=True same-font=True right=\[\]$" "$wd/win.txt" && grep -q "right=[0-9]* %\( \|$\)" "$wd/win.txt" && ! grep -q "right=RADE is working\|right=Your turn\|right=[0-9]* % ·" "$wd/win.txt" && ok || bad "top bar: title, tagline spot, percent only"
# L4: the last card of a test round (after the last step); its text is in the report under its own line, masked. L5: the 2 state texts.
has "view=feedback light=your turn kick=LAST QUESTION sent=Anything else about this round or the app? p=This is optional. Do not type names or addresses. btn=[Continue]" "right= app=" "WIN feedback max=10000 enter=Continue focus=True" "WIN paste ok=True text=line one line two cut=xxxxx joined=a b c note=" "WIN paste-cut ok=True inserted=3 note=The paste was too long: 1,234 characters did not fit. shown=True" "WIN paste-cut one=The paste was too long: 1 character did not fit." "WIN paste-cut none=[]" 'foot=RADE asks you one last question at the end. Until then, keep this window open.' &&
  grep -q "^Other feedback: The second card was slow. Mail <EMAIL>" "$wr" && ! grep -q "someone@\|RADE is waiting for you" "$wd/win.txt" "$wr" && [ "$(cat $engine_src engine/rade_ui.ps1 | grep -c "RADE is waiting for you")" = 0 ] && ok || { bad "r31 L4, L5: the last card, its report line, the state texts"; grep "view=feedback\|Other feedback\|foot=" "$wd/win.txt" "$wr" | cut -c1-260; }
# L7: the now-doing line shows the step's "doing", then a plain sentence for each result line, and a NOW line; none of them is in the log.
# The Administrator, 2026-11-19: each ends with "...", a long one is cut to 2 lines, and the line keeps one height (Cancel does not move).
# L8: a step stays on the Run card for the minimum time (engine/window.json minStepMs; the test user sets it to 0 after this one measure).
has "WIN now=Checking the sample files. shown=Checking the sample files..." "WIN now=Checked: sample check: PowerShell" "WIN now-fit short=Copying the list files...|long-end=True|long-fits=True|same-h=True|empty-shown=True|narrower-fits=True|ellipsis=Done..." "WIN now-text pass=Checked: list there|skip=Skipped: no flow|fail=Needs review: list missing|plain=|none=" "WIN hold ms=120 held=True json=500" && ! grep -q "Checking the sample files" "$wr" && ok || { bad "r31 L7, L8: the now-doing line and the minimum step time"; grep "WIN now\|WIN hold" "$wd/win.txt" | cut -c1-200; }
# L6: the tour comes before the first Choose, 5 cards (Back works), and its end is remembered in RADE\Config; "Help (F1)" is on the Ready
# card, F1 opens the tour from it and its end shows that card again; a run and a hand card have no Help; a second window shows no tour.
# No reader here stops before the end of its input (grep -m1, grep -q): with pipefail, the grep before it then fails on a broken pipe (PR 122 CI).
has "view=tour light=off kick=RADE TOUR · 1 OF 5 sent=RADE installs and tests applications on this computer." "btn=[Skip the tour] [Next]" "kick=RADE TOUR · 3 OF 5 sent=A step that you do has up to three answers." "btn=[Skip the tour] [Next]" "kick=RADE TOUR · 5 OF 5 sent=The Record shows everything." "btn=[Close the tour]" \
  "WIN help link=True name=Help (F1) back-on=ready same=True seen=True" && [ "$(grep -c "^WIN view=tour .* 1 OF 5" "$wd/win.txt")" = 3 ] && [ -s "$wd/u/test1234/OneDrive - United States Air Force/RADE/Config/rade-tour.txt" ] &&
  [ "$(awk '/^WIN view=/ { k++; if (/view=choose/) { print k; exit } }' "$wd/win.txt")" -gt 6 ] 2>/dev/null && [ "$(grep "^WIN view=\(run\|hand\|answer\|feedback\|tour\|boot\|checking\) " "$wd/win.txt" | grep -c "help=True")" = 0 ] && [ "$(grep "^WIN view=ready " "$wd/win.txt" | grep -c "help=True")" -gt 0 ] && ok || { bad "r31 L6: the tour and Help"; grep "view=tour\|WIN help" "$wd/win.txt" | cut -c1-200; }
win 0 done 0 0 "$wd/r31.ps1"
has "view=choose" && ! grep -q "view=tour" "$wd/win.txt" && ok || bad "r31 L6: the tour shows one time only"
# Text mode (no window): a hidden answer is not offered and not taken (S is asked again; Enter is Done), the step with only questions
# is SKIPPED, and the last question is not asked.
printf '1\n\nS\n\n\n' | USERPROFILE="$wd/u/test1234" timeout 120 pwsh -NoProfile -File "$wd/r31.ps1" > "$wd/text.txt" 2>&1
[ "$(grep -c "Press Enter when you have done this step, or type F and Enter if it failed" "$wd/text.txt")" -ge 1 ] && ! grep -q "S and Enter to skip" "$wd/text.txt" && grep -q "^T02 Sample import r1: PASSED (confirmed by you)" "$wr" && grep -q "^T05 Sample questions r1: SKIPPED (its questions need the RADE window)" "$wr" &&
  grep -q "^Other feedback: not asked (text mode)" "$wr" && ok || { bad "r31 text mode: hidden answers, the step with only questions, no last question"; grep "Press Enter\|T02\|T05\|Other feedback" "$wd/text.txt" | cut -c1-200; }
# Text mode: an answer that the step hides, 3 times: the step is skipped with that reason, never as "by you".
printf '1\n\nS\nS\nS\n\n' | USERPROFILE="$wd/u/test1234" timeout 120 pwsh -NoProfile -File "$wd/r31.ps1" > "$wd/text2.txt" 2>&1
grep -q "^T02 Sample import r1: SKIPPED (no answer that this step offers was given)" "$wr" && ! grep -q "^T02 .*by you" "$wr" && ok || { bad "r31 text mode: a hidden answer is never recorded"; grep "^T02" "$wr"; }
# A bad field stops the build, and the manifest check finds it too (one manifest for each fault).
python3 - "$t" <<'P' && ok || bad "r31: the build and the manifest check reject a bad hide, answersOnly, failOn or showIf"
import copy, json, pathlib, shutil, subprocess, sys
t = pathlib.Path(sys.argv[1]); a = t / 'r31x' / 'app'; shutil.copytree(t / 'r31' / 'app', a)
base = json.load(open(a / 'scripts' / 'paste_bundles.json'))
def step(m, n): return [s for s in m['bundles'][0]['steps'] if s['name'].startswith(n)][0]
def c1(m): step(m, 'T02')['hide'] = ['done', 'failed', 'skip']
def c2(m): step(m, 'T01')['hide'] = ['skip']
def c3(m): step(m, 'T05')['guide'] = ['1. Look.']
def c4(m): step(m, 'T02')['answers'][0]['failOn'] = ['No']
def c5(m): step(m, 'T05')['answers'][0]['failOn'] = ['A word that is no answer']
def c6(m): step(m, 'T05')['answers'][0]['showIf'] = {'key': 'more', 'in': ['Yes']}
def c7(m): step(m, 'T05')['answers'][1]['showIf'] = {'key': 'page', 'in': ['Maybe']}
def c8(m): del step(m, 'T05')['answers']
def c9(m): step(m, 'T02')['hide'] = ['done']
cases = [(c1, 'hide: only for a guide step'), (c2, 'hide: only for a guide step'), (c3, 'no Done card (so without: guide)'), (c4, 'failOn (only in a step with "answersOnly"'), (c5, 'failOn (only in a step with'),
         (c6, 'showIf needs "key" (an earlier'), (c7, 'showIf needs "key" (an earlier'), (c8, 'answersOnly: true, only for a guide step'), (c9, 'not done when the step has answers')]
for change, want in cases:
    m = copy.deepcopy(base); change(m); json.dump(m, open(a / 'scripts' / 'paste_bundles.json', 'w'))
    b = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(a)], capture_output=True, text=True)
    c = subprocess.run([sys.executable, 'scripts/check_manifest.py', str(a / 'scripts' / 'paste_bundles.json')], capture_output=True, text=True)
    assert b.returncode != 0 and want in (b.stdout + b.stderr), (want, (b.stdout + b.stderr)[-300:])
    assert c.returncode != 0, (want, c.stdout[-300:])
P
# A deploy asks no last question.
! grep -q "view=feedback" "$t/w1/win.txt" && ! grep -q "^Other feedback" "$t/w1/u/test1234/OneDrive - United States Air Force/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && ok || bad "r31 L4: a deploy has no last question"
echo "GROUP $pass $fail"; } > "$t/grp-W4.log" 2>&1 &
