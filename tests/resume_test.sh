# RADE engine tests, part of tests/engine_test.sh (sourced there; uses its $t, ok, bad, go, psrun and the built sample).
# Pause and resume (docs/engine.md "Pause and resume"; the Administrator, 2026-11-20) and no scripts in results (the Administrator,
# 2026-11-20): the engine parts on their own (tests/resume_unit.ps1), a text-mode round that resumes, and the build
# check of collect names; and the Maintenance tools (tests/tools_unit.ps1). Group R runs in the background in its own users folder ($t/ru).
# Network: none.
# Writes: only under $t (the temporary folder of tests/engine_test.sh).
# Credentials: none.
go R; {   # group R: runs in the background (see "go" in tests/engine_test.sh)
mkdir -p "$t/ru-unit"
pwsh -NoProfile -File tests/resume_unit.ps1 "$t/ru-unit" > "$t/resume-unit.txt" 2>&1
grep -q "^RESUME-UNIT pass=[1-9][0-9]* fail=0$" "$t/resume-unit.txt" && ok || { bad "resume: engine parts (tests/resume_unit.ps1)"; grep -v "^PASS" "$t/resume-unit.txt"; }
# The Maintenance tools Diagnose and Back up (engine-v30), with the fake PnP: tests/tools_unit.ps1.
mkdir -p "$t/tools-unit"; pwsh -NoProfile -File tests/tools_unit.ps1 "$t/tools-unit" > "$t/tools-unit.txt" 2>&1
grep -q "^TOOLS-UNIT pass=[1-9][0-9]* fail=0$" "$t/tools-unit.txt" && ok || { bad "tools: Diagnose and Back up (tests/tools_unit.ps1)"; grep -v "^PASS" "$t/tools-unit.txt"; }
sed "s#usersRoot = '$t/u'#usersRoot = '$t/ru'#" "$t/b.ps1" > "$t/r.ps1"; rod="$t/ru/test1234/OneDrive - United States Air Force"; mkdir -p "$rod"
rr="$rod/RADE/SampleApp/Rounds/R01"; rs="$rr/rade-state.json"; rrep="$rr/SAMPLE-R01-report-r1.txt"
bid=$(sed -n "s/^\$buildId = '\([0-9a-f]*\)'$/\1/p" "$t/b.ps1")
# state BUILD: writes a round state of the sample test app in which T01 PASSED (its line carries a marker word).
state() { python3 - "$rs" "$1" <<'P'
import json, sys
names = ['T01 Sample check r1', 'T04 Sample optional r1', 'T02 Sample import r1', 'T03 Sample verify r1']
json.dump({'schema': 'rade-state/1', 'round': 'R01', 'build': sys.argv[2], 'app': 'Sample app', 'saved': '2026-11-20T09:00:00',
           'selected': names, 'steps': [{'name': names[0], 'state': 'PASSED', 'lines': [names[0] + ': PASSED (kept-marker) in 1s'], 'made': []}],
           'log': ['earlier-log-marker']}, open(sys.argv[1], 'w'))
P
}
# 1. A round that ends leaves no state file (nothing to resume).
psrun "$t/r.ps1" "$t/outr1.txt" $'1\n\n\n\n' USERPROFILE="$t/ru/test1234"
[ -f "$rrep" ] && [ ! -f "$rs" ] && ok || { bad "resume: a round that ends removes its state file"; tail -5 "$t/outr1.txt"; ls "$rr"; }
# 2. Resume: the same build offers "Resume at step N of M"; R keeps the passed step and runs the rest; the earlier log comes back.
state "$bid"
psrun "$t/r.ps1" "$t/outr2.txt" $'1\nR\n\n\n\n' USERPROFILE="$t/ru/test1234"
grep -q "^Resume at step 2 of " "$t/outr2.txt" && grep -q "T01 Sample check r1: kept from the earlier run (PASSED), not run again" "$t/outr2.txt" \
  && grep -q "^T01 Sample check r1: PASSED (kept-marker) in 1s" "$rrep" && grep -q "^Resumed: 1 finished steps kept" "$rrep" \
  && grep -q "^earlier-log-marker" "$rrep" && grep -q "^Clean-up: not run again (the round resumed)" "$rrep" && [ ! -f "$rs" ] && ok \
  || { bad "resume: a resumed round keeps the passed step"; grep -n "Resum\|kept\|^Step " "$t/outr2.txt" | head; }
# 3. Start over: S moves the state away and the round runs every step.
state "$bid"
psrun "$t/r.ps1" "$t/outr3.txt" $'1\nS\n\n\n\n' USERPROFILE="$t/ru/test1234"
grep -q "^Start over: the saved progress is in the Recycle Bin" "$t/outr3.txt" && ! grep -q "kept from the earlier run" "$t/outr3.txt" \
  && ! grep -q "kept-marker" "$rrep" && ok || { bad "resume: start over"; grep -n "Start over\|kept" "$t/outr3.txt" | head; }
# 4. Build mismatch: a state of another build of this round never resumes.
state 00000000
psrun "$t/r.ps1" "$t/outr4.txt" $'1\n\n\n\n' USERPROFILE="$t/ru/test1234"
grep -q "^Saved progress of another build of this round was not used" "$t/outr4.txt" && ! grep -q "kept from the earlier run" "$t/outr4.txt" \
  && ok || { bad "resume: another build is not resumed"; grep -n "Saved\|kept" "$t/outr4.txt" | head; }
# 5. Corrupt state file: a plain message, then the round starts over.
printf '{ "schema": "rade-' > "$rs"
psrun "$t/r.ps1" "$t/outr5.txt" $'1\n\n\n\n' USERPROFILE="$t/ru/test1234"
grep -q "^The saved progress of this round could not be read (the file is not valid JSON), so the round starts over" "$t/outr5.txt" \
  && grep -q "^Step 1 of " "$t/outr5.txt" && ok || { bad "resume: a corrupt state file starts over"; head -20 "$t/outr5.txt"; }
# 6. No scripts in results: the build refuses a collect name that can match a script file (a pattern that ends in * or ?,
# or that names a script extension); a pattern with its own extension builds.
for nm in 'SAMPLE-T01-feedback-*' 'SAMPLE-T01-*.ps1' 'SAMPLE-T01-r1.CMD' 'run.p?1' 'SAMPLE-T01-*1' 'SAMPLE-T01-*.pdf;SAMPLE-*.bat'; do
  rm -rf "$t/rc"; mkdir -p "$t/rc"; cp -r "$t/app" "$t/rc/app"
  python3 -c "import json,sys; p=sys.argv[1]; m=json.load(open(p)); m['bundles'][0]['collect'][0]['name']=sys.argv[2]; json.dump(m,open(p,'w'))" "$t/rc/app/scripts/paste_bundles.json" "$nm"
  if python3 engine/rade_build.py --app-root "$t/rc/app" > "$t/rc.txt" 2>&1; then bad "collect: the build accepts $nm"
  else grep -q "can match a script file" "$t/rc.txt" && ok || { bad "collect: no reason for $nm"; cat "$t/rc.txt"; }; fi
done
python3 -c "import json,sys; p=sys.argv[1]; m=json.load(open(p)); m['bundles'][0]['collect'][0]['name']='SAMPLE-T01-*.pdf;*.txt'; json.dump(m,open(p,'w'))" "$t/rc/app/scripts/paste_bundles.json"
python3 engine/rade_build.py --app-root "$t/rc/app" > "$t/rc.txt" 2>&1 && ok || { bad "collect: a pattern with its own extension must build"; cat "$t/rc.txt"; }
grep -q "^\$scriptExts = @('.ps1', " "$t/b.ps1" && ok || bad "collect: the bundle carries the script extension list"
echo "GROUP $pass $fail"; } > "$t/grp-R.log" 2>&1 &
