#!/usr/bin/env bash
# RADE engine tests, the window part: sourced by tests/engine_test.sh (its section "window"), never run alone. Split out
# of engine_test.sh by the speed audit of 2026-11-17 (docs/code-standard.md C4: a file is at most 600 lines). Uses what
# engine_test.sh defined before it: $t, $b, $engine_src, swap, go, ok and bad. Starts the background groups W, W2 and W3;
# engine_test.sh "gather" waits for them and adds their counts.
# Network: none. Writes: temporary files under the test folder $t, deleted on exit. Credentials: none.

# ---- window: the "One thing" window (docs/window-design.md) with stand-in Windows Forms types (tests/window_stub.cs) and
# a scripted user (tests/window_driver.ps1) that prints one WIN line per card, runs every Paint handler and checks names.
# wgo DIR [seed]: a window group's own folder $t/DIR ($wd): its users root, its bundle copies and its win.txt. The window
# runs are 3 groups (W, W2, W3) that run at once: one chain of 12 runs took about 75 s (speed audit, 2026-11-17). W2 and W3
# start from a copy of the users root as window run 1 (the first deploy) left it ($t/wseed, made by W): an installed app.
wgo() { wd="$t/$1"; mkdir -p "$wd/u/test1234/OneDrive - United States Air Force"; swap "$b" "$wd/wb.ps1" "$wd/u"
  if [ -n "${2:-}" ]; then until [ -e "$t/wseed.done" ]; do sleep 0.2; done; cp -a "$t/wseed/." "$wd/u/"; fi; }
# stub: the stand-in types for win, as the DLL that group W compiles once before its first run ($t/window_stub.dll), or
# the C# source when there is no DLL (each run then compiles it: about 0.8 s of CPU more for each of the 12 runs).
stub() { if [ -s "$t/window_stub.dll" ]; then echo "$t/window_stub.dll"; else echo "$PWD/tests/window_stub.cs"; fi; }
# win APP HAND RECORD TOUR [BUNDLE]: runs the window for application APP (0 = test, 1 = deploy); output in $wd/win.txt.
win() { sed -E -e 's#Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing#$null = 0#' -e "s#^\\\$sitePrefix = 'https://usaf.dps.mil/sites/'#\$sitePrefix = 'https://rade-test.invalid/sites/'#" -e 's#System\.Drawing\.(FontStyle|Font|Pen|SolidBrush|Image|Graphics)\b#RadeDraw.\1#g' "${5:-$wd/wb.ps1}" > "$wd/wb2.ps1"
  cat tests/window_driver.ps1 "$wd/wb2.ps1" > "$wd/w.ps1"
  RADE_T_FAULT="${fault:-}" RADE_T_CANCEL="${cancel:-}" RADE_T_START="${start:-}" RADE_T_LINK="${link:-}" RADE_T_SCALE="${scale:-}" RADE_T_LOOP="${loop:-}" RADE_T_STUB="$(stub)" RADE_T_APP="$1" RADE_T_HAND="$2" RADE_T_RECORD="$3" RADE_T_TOUR="$4" USERPROFILE="$wd/u/test1234" timeout 180 pwsh -NoProfile -File "$wd/w.ps1" < /dev/null > "$wd/win.txt" 2>&1; }
# has TEXT...: every text is in the window output, and the window did not fall back to text mode or miss a name.
has() { local x; grep -q "No window could open\|WIN NONAME\|WIN NOFOCUS\|WIN BAD" "$wd/win.txt" && { grep -m3 "No window could open\|WIN NONAME\|WIN NOFOCUS\|WIN BAD" "$wd/win.txt" | cut -c1-300; return 1; }; for x in "$@"; do grep -qF -- "$x" "$wd/win.txt" || { echo "  missing: $x"; return 1; }; done; grep -q "^WIN closed=True" "$wd/win.txt"; }
go W; {   # group W: runs in the background (see "go" in tests/engine_test.sh)
wgo w1
RADE_T_STUB="$PWD/tests/window_stub.cs" RADE_T_STUB_OUT="$t/window_stub.dll" pwsh -NoProfile -File tests/window_driver.ps1 > "$t/stub.txt" 2>&1 || cat "$t/stub.txt"
# 1. A first deploy: boot, choose with the newer-version notice, ready, the Record (boxes can change, Clean-up off), the hand step, done.
win 1 done 1 0; cp -a "$wd/u" "$t/wseed"; : > "$t/wseed.done"   # the seed of W2 and W3 (wgo)
has "view=boot" "view=choose light=off kick= sent=Which application do you want to install?" "2 Sample app (deploy) 1.0.0 NOTE Version 9.0.0 is on the RADE page" "view=ready light=off kick=ALL 8 CHECKS PASSED sent=Ready to install Sample app (deploy) 1.0.0." \
  "WIN record on=True rows=10 boxes=5 enabled=True text=True name=True reused=Last check: 14 Nov 26 / Version [5.1] tall=True" "WIN paged=" "WIN record on=False clean=False" "view=hand light=RADE is waiting for you kick=STEP 2 OF 3 · YOUR TURN sent=Import the sample flow" "btn=[Imported] [It failed] [Skip]" \
  "view=done light=off kick=ALL STEPS PASSED sent=Sample app (deploy) 1.0.0 is installed. p=Nothing was sent." "btn=[Start Sample app (deploy)] [Close] [Record] [Open results folder] [Copy summary]" "WIN made=True log=True locked=True" "WIN copied=True" && ! grep -q "foot=Site\|Change the site address" "$wd/win.txt" && ok || { bad "window 1: first deploy"; tail -5 "$wd/win.txt" | cut -c1-300; }
# 1a. The polish pass of 17 Nov (docs/window-design.md "Type", "Cards"): the manifest title is what the window shows (the hand card's
# headline, the step line of a run, the Record's step boxes and their accessible names, the foot of the Run card), a step with no title shows
# its name, and the report keeps the name; the hand card shows the step note under the headline, then the address row, then the numbered
# lines (a line without a number goes after the list, small and gray), then the one closing line (with the step's doneText), above the
# buttons; one typeface in 4 styles ($ui.F has only those tokens; every button has the strong font, also a plain one; Consolas is only the
# Record's text box); the last log line is small.
has "view=hand light=RADE is waiting for you kick=STEP 2 OF 3 · YOUR TURN sent=Import the sample flow p=You do this step in the browser. RADE cannot do it for you. steps=1. Open the import page. ~ 2. Choose the file on the clipboard. ~ 3. Select Import. rest=RADE cannot see the import page, so it asks you to confirm. close=When you finish in the browser, come back to this window and select \"Imported\"." \
  "step=Check this computer lastlog-font=Segoe UI10" "step=T03 Sample verify r1" 'foot=RADE needs you next at "Import the sample flow". Until then, keep this window open.' \
  "box-text=Clean-up|1  Check this computer|2  T04 Sample optional r1|3  Import the sample flow  (needs you)|4  T03 Sample verify r1 box-name=1  Check this computer" \
  "WIN hand-order address-above-lines=True lines-above-path=True path-above-links=True closing-above-buttons=True closing-gap=4" "WIN F tokens=Body,Link,Mono,Sent,Small,SmallB,Word mono-only-in-record=True sent=Segoe UI Semibold22 body=Segoe UI12 small=10 smallb=Segoe UI Semibold10 help=12 kick=Segoe UI Semibold label=Segoe UI Semibold plainbtn=Segoe UI Semibold link=Segoe UI Semibold lastlog=Segoe UI" && ok || { bad "window 1a: titles, hand card order, type styles"; grep "view=hand\|step=\|box-text\|WIN F\|hand-order\|BAD" "$wd/win.txt" | cut -c1-700; }
# 1a2. R28 fixes (rhope-ops/90-161.Z round R28, the PFM's notes): N4 the lines of a hand step are ONE selectable rich text (numbers in a
# right-aligned column by a right tab, text in a hanging indent); copying across lines gives the lines as written (no tabs) and a path that
# RADE broke to fit copies whole; N1 a step with no address has no address row, a closing line without "browser", and the focus on its text
# (Enter answers nothing); N6 the hand card shows the file's full path; N10 the step line has the time in the step ("4m 12s"); N8 the install
# card of a deploy asks for the folder of the RADE shortcut; the Done card of a first install has Start (it was missing in R28).
has "WIN guide one-box=True rtf=True selectable=True" "WIN guide-copy=1. Open the import page.|2. Choose path-copy=C:\\ab.zip" "WIN elapsed=4m 12s|0m 05s|1h 02m 05s" \
  'WIN no-address field=False close=When you finish, select "Imported". focus-text=True accept=False' "/RADE/SampleApp/T02/SAMPLE-T02-import-r1.zip" "time=0m 0" \
  "view=ready light=off kick=ALL 8 CHECKS PASSED" "field=RADE shortcut in:" && ok || { bad "window 1a2: R28 fixes on the hand, run and ready cards"; grep "WIN guide\|WIN elapsed\|no-address\|path=\|time=\|field=" "$wd/win.txt" | cut -c1-300; }
[ "$(cat $engine_src engine/rade_ui.ps1 | grep -c Consolas)" = 1 ] && grep -q "Mono = (& \$ui.Font 'Consolas' 9" engine/rade_ui.ps1 && [ "$(cat $engine_src engine/rade_ui.ps1 | grep -c 'F\.Mono')" = 1 ] && grep -q "RecText.Font = \$ui.F.Mono" $engine_src && ok || bad "type: Consolas is only the Mono token, and only the Record's text box uses it"
wr="$wd/u/test1234/OneDrive - United States Air Force/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"
! grep -q "Import the sample flow\|Check this computer" "$wr" && grep -q "^T01 Sample check r1: PASSED" "$wr" && grep -q "^T02 Sample import r1: PASSED (confirmed by you)" "$wr" && ok || { bad "title: the report keeps the step name and never shows the title"; grep -n "Import the sample flow\|Check this computer" "$wr"; }
# 1b. The hand step's questions after Done: one card each (No, the second choice, a text with an e-mail address), and
# their lines under the step's line in the report, the text masked (docs/engine.md "Step contract").
wr="$wd/u/test1234/OneDrive - United States Air Force/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"
has "view=answer light=RADE is waiting for you kick=STEP 2 OF 3 · QUESTION 1 OF 3 sent=Did the flow run start? p= btn=[Yes] [No]" "kick=STEP 2 OF 3 · QUESTION 2 OF 3 sent=How many flows does the import page show? p= btn=[One] [Two] [Three or more]" \
  "kick=STEP 2 OF 3 · QUESTION 3 OF 3 sent=Anything else to report? p=Do not type names or addresses. btn=[Continue]" "WIN answer-box max=2000 enter=Continue focus=True" && [ "$(grep -c "^WIN view=answer" "$wd/win.txt")" = 3 ] &&
  [ "$(grep -A3 "^T02 Sample import r1: PASSED (confirmed by you) in " "$wr" | tail -3 | tr -d '\r' | tr '\n' '|')" = "  Answer run-started: No|  Answer flow-count: Two|  Answer note: Mail <EMAIL> about it|" ] && ! grep -q "someone@" "$wr" && ok || { bad "window 1b: the answer cards and the answers in the report"; grep -A3 "^T02 Sample" "$wr"; grep "view=answer\|answer-box" "$wd/win.txt" | cut -c1-300; }
# 1b2. After a deploy that passed (R28): RADE keeps a copy of the pasted text as the installed runner, and says in plain words what it did about the
# desktop shortcut (here no Desktop folder exists, so it says it made none; the .lnk itself is made with WScript.Shell on Windows only).
rn="$wd/u/test1234/OneDrive - United States Air Force/RADE/rade-runner.ps1"
[ -f "$rn" ] && grep -q "^\$buildId = '" "$rn" && grep -q "^\$engineRelease = [0-9]" "$rn" && grep -qF "RADE could not find your Desktop folder, so it made no desktop shortcut. Open RADE from the RADE page instead." "$wd/win.txt" && ok || bad "window 1b2: installed runner copy and the desktop shortcut line"
# 1c. A minimized window comes back when RADE needs the person; it has its own taskbar button (Application.Run: no owner).
# The layout line and the SCALE line at 100 %; the sizes RADE sets after the form has scaled, at 100 % (the same numbers as
# before the one scale source: tests/window_driver.ps1 "WIN measure").
has "WIN restored=Normal taskbar=True minbox=True shown-by=Run" "WIN layline=Layout self-check: PASS layout, 0 cards (1216 x 684 at 100 %) ~ SCALE dpiX=96 deviceDpi=n/a mode=Dpi asd=96x96 autoScale=96x96 font=17 fontPt=10 fontScale=1 ctlScale=1 realDpi=n/a aware=n/a screen=1280x800 work=1280x720 client=1216x684 state=Normal logo=40x40 btn=400x40" \
  "WIN measure choice h=110 gap=8 plan-x=54" "WIN measure record box=5,4 label=5,6 rows=268" && ok || { bad "window 1c: restore, taskbar, the scale line"; grep "restored=\|layline=" "$wd/win.txt" | cut -c1-300; }
# 1d. Polish after the R24 pictures (docs/window-design.md "Sizes"): the header and the label-box-button rows share one
# midpoint within 1 px (from margins and sizes; an odd height gives a half pixel; the stand-ins have no layout), a box is as tall as a compact button, gaps of 8; the
# question headline is the prompt's first sentence (one sentence: no body line; two: the rest is the body line, 1b) and a
# first sentence too long for one line shrinks (22 pt, floor 13.2 pt = 60 %; the stand-ins' card is 258 px); the self-check's alignment rules pass an aligned fixture
# and give one LAYOUT line for each fault of a misaligned one (a box 6.5 px off, a button 3 px off, box 23 vs button 30, a headline 3 px right).
has "WIN mid hand label=18.5 box=19 button=19 box-h=30 button-h=30 gaps=8,8 inner=148/160 tick=0" "WIN mid header logo=20 word=20 app=19.5" "WIN mid answer label=18.5 box=19 h=30" \
  'WIN sent-pt=22 for "Did the flow run start?"' 'WIN sent-pt=22 for "Anything else to report?"' 'WIN sent-pt=13.2 for "How many flows does the import page show?"' \
  "WIN rule aligned=0 misaligned=4 ~ LAYOUT fixture FieldRow FieldBox midpoint: 15.5, the row midpoint is 22 ~ LAYOUT fixture FieldRow FieldB midpoint: 19, the row midpoint is 22 ~ LAYOUT fixture FieldRow heights: box FieldBox 23, button FieldB 30 ~ LAYOUT fixture Sent edge: starts at 126, the card edge is 123 (Kick)" && ok || { bad "window 1d: alignment, question headline, alignment rules"; grep "WIN mid\|sent-pt\|WIN rule" "$wd/win.txt" | cut -c1-300; }
# 1f. Review of b093036: a click within 400 ms of a new card does nothing (a double-click on Done answers no question
# unseen; Enter clicks the same buttons); a word wider than the line is cut into pieces that fit, and the self-check
# reports a word of a wrapping label that is wider than the label; the Record's step boxes are one line that ends with
# "..." (R24 job: "(needs you)" was cut to "(ne"), shortened by RADE (no AutoEllipsis: no tooltip); the click guard runs on a
# monotonic clock (a reference "in the future", as after the clock stepped back, never blocks; 401 ms after a card the click
# is taken, 100 ms after it is not); long words break by text element (a surrogate pair stays whole) and in body lines too.
has "WIN measure record box=5,4 label=5,6 rows=268 one-line=True" "WIN guard held=True then=Yes" "WIN break=abc|def|ghi|j word-bad=LAYOUT fixture P0 text: the word \"abcdefghij\" needs 70, the line is 50 word-ok=True" && ok || { bad "window 1f: click guard, long words"; grep "WIN guard\|WIN break" "$wd/win.txt" | cut -c1-300; }
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
has "opts=OFF Sample app; 1 Sample app (deploy) 1.0.0" "btn=[Check this computer again]" "view=maint light=off kick=SAMPLE APP (DEPLOY) 1.0.0 · INSTALLED " "sent=Maintenance" "p=Repair adds what is missing and keeps your data. / Start runs the checks, then opens Sample app (deploy)." "btn=[Start Sample app (deploy)] [Repair] (Diagnose) (Back up) (Restore) (Uninstall)" \
  "view=site light=off kick= sent=Which site does the application go to?" "WIN site-note=The address must look like https://rade-test.invalid/sites/name" "view=fail light=failed kick=CHECK 9 OF 11 · FAILED sent=One check failed. p=Your SharePoint site can be reached" "btn=[Run checks again] [Change the site address]" "WIN esc" "WIN again" "sent=One check failed. p=You can change the site (sign in with your CAC) / Sign-in was not finished" "btn=[Sign in and check site rights] [Change the site address]" \
  "view=need light=RADE is waiting for you kick=CHECK 10 OF 11 · YOUR TURN sent=One check needs you." "btn=[Sign in and check site rights]" "btn=[Check Power Automate]" "sent=Check Power Automate" "btn=[Yes: I see both] [No: one is missing] [Not now]" "steps=1. Select Open in browser. Power Automate opens; sign in with your CAC if asked. ~ 2. Look at the left menu" "rest=You look in Power Automate and answer (about 2 minutes, an estimate). Nothing is changed. close=When you finish in the browser, come back to this window and select \"Yes: I see both\"." "kick=ALL 11 CHECKS PASSED" "btn=[Start Sample app (deploy)] [Install] [Record] [Change the site address] foot=Site: fake" "WIN start-button=Start Sample app (deploy) main=Start Sample app (deploy)" \
  "view=handfail" "view=review light=failed kick=NEEDS REVIEW sent=The install is not complete. p=T02 Sample import r1: FAILED (reported by you)" "flow <SITE> not found" "help=For help, ask in the Teams channel" "btn=[Copy summary] [Open results folder] [Record] [Close]" && [ "$(grep -c "^WIN view=maint" "$wd/win.txt")" = 2 ] && [ "$(grep -c "^WIN view=fail .*CHECK 9 OF 11" "$wd/win.txt")" = 2 ] && ! grep -q "^WIN view=answer" "$wd/win.txt" && ok || { bad "window 2: Maintenance, checks that fail or need you, needs review (and no question after It failed)"; tail -5 "$wd/win.txt" | cut -c1-300; }
# 2b. Start (R28): the installed application has the Start button; selecting it runs the start script of the local copy in its own
# powershell.exe process and closes RADE. A test application (no start script) has none.
start=1 win 1 done 0 0
has "WIN start-button=Start Sample app (deploy) main=Start Sample app (deploy)" "WIN start-process powershell.exe" "WIN started=True closed=True" && ok || { bad "window 2b: Start"; grep "start" "$wd/win.txt" | cut -c1-200; }
# 2b2. Start on Maintenance (R28 fix): it runs the checks, then starts the application (no Ready card click), and RADE closes.
start=maint win 1 done 0 0
has "view=maint" "btn=[Start Sample app (deploy)] [Repair]" "view=ready " "WIN start-process powershell.exe" "WIN maint-start started=True closed=True" && ok || { bad "window 2b2: Start on Maintenance"; grep "maint\|start\|view=ready" "$wd/win.txt" | cut -c1-200; }
# 2c. Cancel on the checking card (in group W: it runs on the install state that 1 to 2b2 left, as before the split).
cancel=1 win 1 done 0 0
has "WIN cancel busy=" "view=checking light=off kick= sent=Checking this computer and your access." "btn=[Cancel]" "view=run " && [ "$(grep -c "^WIN view=choose" "$wd/win.txt")" -ge 2 ] && ok || { bad "window 2c: Cancel on the checking card"; grep "WIN cancel\|view=checking\|view=choose" "$wd/win.txt" | cut -c1-200; }
echo "GROUP $pass $fail"; } > "$t/grp-W.log" 2>&1 &
go W2; {   # group W2: runs in the background (see "go" in tests/engine_test.sh)
wgo w2 seed
# 2c. States (R28): a boot error, a paste with no application and Cancel on the checking card each have a card (and the run card has Cancel).
fault=boot win 0 done 0 0
has "view=boot" "view=booterr light=failed kick=STOPPED sent=RADE could not check this computer. p=The test made the boot checks fail / Nothing was changed. / What to do: select \"Try again\"." "btn=[Try again] [Close]" "help=For help, ask in the Teams channel" "view=choose" && ok || { bad "window 2c: boot error card"; grep "view=booterr" "$wd/win.txt" | cut -c1-300; }
fault=noapps win 0 done 0 0
has "view=noapps light=failed kick=NOTHING TO CHOOSE sent=No application is listed in this paste." "btn=[Close]" && ok || { bad "window 2c: no application card"; grep "view=noapps" "$wd/win.txt" | cut -c1-300; }
# 3. A test round: the owner's test extras show on Done; a deploy never shows them (1 and 2 have no "test=shown").
# Here Application.Run fails as when a message loop already runs on the thread: the window opens with ShowDialog.
loop=1 win 0 done 0 0
has "shown-by=ShowDialog" "sent=Ready to run round R01." "view=done light=off kick=ALL STEPS PASSED sent=Round R01 is done." "test=shown" "WIN draft-note=The Outlook draft could not be created" && ! grep -q "Sample app (deploy).*test=shown" "$wd/win.txt" && ok || { bad "window 3: test round"; tail -5 "$wd/win.txt" | cut -c1-300; }
# 4. A deploy whose download fails: stopped, with the help line.
sed "s#file://$t/app/flow/SAMPLE-data#file://$t/app/flow/NOPE#" "$wd/wb.ps1" > "$wd/wf.ps1"
win 1 done 0 0 "$wd/wf.ps1"
has "view=stopped light=failed kick=STOPPED sent=The install stopped. p=A file this install needs could not be downloaded" "help=For help, ask in the Teams channel" "btn=[Copy the log] [Try again] [Close]" && ok || { bad "window 4: stopped"; tail -5 "$wd/win.txt" | cut -c1-300; }
echo "GROUP $pass $fail"; } > "$t/grp-W2.log" 2>&1 &
go W3; {   # group W3: runs in the background (see "go" in tests/engine_test.sh)
wgo w3 seed
# 5. The R24 device case: the form scales 1.5 x (144 dpi) while the screen dpi says 96. What RADE sizes after the form has
# scaled follows the form: a drawn part (the text start of a choice: 54 -> 81), a control made later (the gap under a
# choice: 8 -> 12; the Record's step box and label margins: 5,4 -> 8,6 and 5,6 -> 8,9). The stand-ins have no layout and
# no fonts: text heights, the logo and the buttons made before the form scaled stay at their coded sizes here, and the
# layout self-check does not run (the Windows job and a round on a work computer measure those).
mkdir -p "$t/lnk"; link="$t/lnk" scale=150 win 1 done 1 0
has "WIN measure choice h=120 gap=12 plan-x=81" "WIN measure record box=8,6 label=8,9 " "(1280 x 720 at 150 % (the form auto-scale; the screen dpi says 100 %)) ~ SCALE dpiX=96 deviceDpi=n/a mode=Dpi asd=96x96 autoScale=144x144 " "fontPt=15 fontScale=1.5 ctlScale=1.5 " && ok || { bad "window 5: scale 150 % with a 96 dpi screen"; grep "measure\|layline" "$wd/win.txt" | cut -c1-300; }
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
