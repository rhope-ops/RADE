#!/usr/bin/env bash
# RADE engine tests (run by scripts/check.local.sh). Pass = last line "ENGINE pass=N fail=0".
# Builds the sample manifest (schemas/examples/sample-manifest.json + tests/fixture-app) into a bundle and runs it in
# pwsh text mode (Linux has no Windows Forms: the window path is not tested here), with C:\Users swapped for a temp root.
# Covers deploy v1 (docs/engine.md): a deploy sends nothing and keeps RADE\Config\rade-installed.json; a test round is unchanged.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
command -v pwsh >/dev/null || { echo "FAIL pwsh is missing (PowerShell 7: see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)"; echo "ENGINE pass=0 fail=1"; exit 1; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
od="$t/u/test1234/OneDrive - United States Air Force"; cfg="$od/RADE/Config"; inst="$cfg/rade-installed.json"
mkdir -p "$od" "$t/app/scripts"; cp -r tests/fixture-app/. "$t/app/"; cp schemas/examples/sample-manifest.json "$t/app/scripts/paste_bundles.json"
: > "$t/go.md"
mkdir -p "$od/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$od/RADE/SampleApp/Config/SAMPLE-site.txt"
build() { python3 engine/rade_build.py --app-root "$t/app" > "$t/build.txt" 2>&1 || { cat "$t/build.txt"; return 1; }
  sed -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$t/u'#" -e "s#^\$goUrl = '.*'#\$goUrl = 'file://$t/go.md'#" -e "s#\$checkGate = \$true#\$checkGate = \$false#" \
    -e "s#https://example-org.github.io/sample-app#file://$t/go.md#g" -e "s#https://example.invalid/import#file://$t/go.md#" "$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" > "$t/b.ps1"; }
# $1 = the number typed on the Choose question (1 = test app, 2 = deploy app); $2 = the answer in the guide step
# (empty = done, S = skip); the other questions get Enter. Not tested here: the window (Windows Forms) and Windows PowerShell 5.1.
round() { printf '%s\n\n%s\n\n' "$1" "${2:-}" | USERPROFILE="$t/u/test1234" pwsh -NoProfile -File "$t/b.ps1" > "$t/out.txt" 2>&1; }
js() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); a=d['apps']['SampleApp/Sample app (deploy)']; print(d['schema'], len(d['apps']), (a['installed'] or {}).get('version'), a['lastRun']['version'], a['lastRun']['state'])" "$inst" 2>&1; }

build && ok || bad "build of the sample bundle"
b="$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1"
grep -q "Name = 'Sample app (deploy)'.*Mode = 'deploy'; Version = '1.0.0'" "$b" && ! grep "Name = 'Sample app (deploy)'" "$b" | grep -q "'outlook'" && ok || bad "catalog: deploy app has Mode, Version and no outlook check"
grep "Name = 'Sample app'" "$b" | grep -q "'outlook'.*Mode = 'test'; Version = ''" && ok || bad "catalog: test app keeps the outlook check and Mode test"

# 0. A skipped step: the run is PASSED but the version is not recorded as installed (review of deploy v1).
round 2 S; cp "$t/out.txt" "$t/out0.txt"
grep -q "^Note: some steps were off or skipped, so version 1.0.0 is not recorded as installed" "$t/out.txt" && [ "$(js)" = "rade-installed/1 1 None 1.0.0 PASSED" ] && ok || { bad "deploy 0: skipped step ($(js))"; tail -8 "$t/out.txt"; }

# 1. First deploy: every step on, PASSED, version recorded, nothing sent.
round 2
grep -q "^Mode: deploy, version 1.0.0 (not installed yet)" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && grep -q "^Mode: deploy, version 1.0.0 (not installed yet)" "$t/out.txt" && ok || { bad "deploy 1: report has the mode line"; tail -30 "$t/out.txt"; }
# Item 3, safe second run: T01 PASSED in run 0, so it is off now; only the two steps left run, and the version is installed.
grep -q "^Step 1 of 2: T02 Sample import r1" "$t/out.txt" && ! grep -q "contract=1" "$t/out.txt" && grep -q "^T01 Sample check r1: already done for version 1.0.0, not run again" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && ok || { bad "item 3: a step that PASSED must start off"; grep "^Step " "$t/out.txt"; }
grep -q "^Version 1.0.0 of Sample app (deploy) is recorded as installed" "$t/out.txt" && grep -q "^DONE in .*Nothing was sent\.$" "$t/out.txt" && ok || bad "deploy 1: DONE line says nothing was sent"
! grep -qi "outlook\|e-mail\|draft\|Summary copied" "$t/out.txt" && ok || { bad "deploy 1: output names Outlook, an e-mail, a draft or a copied summary"; grep -i "outlook\|e-mail\|draft\|Summary copied" "$t/out.txt"; }
[ ! -e "$cfg/rade-mail-to.txt" ] && ok || bad "deploy 1: an e-mail address file was written"
[ "$(js)" = "rade-installed/1 1 1.0.0 1.0.0 PASSED" ] && ! grep -q "test1234\|$t" "$inst" && ok || { bad "deploy 1: rade-installed.json ($(js))"; cat "$inst"; }

# Item 3: the step that needs the skipped hand step is skipped too ("after").
grep -q "^    Skipped: it needs .T02 Sample import r1. to pass first" "$t/out0.txt" && grep -q "^  Result: SKIPPED (it needs .T02 Sample import r1. to pass first)" "$t/out0.txt" && ok || { bad "item 3: a step whose needed step was skipped must be skipped"; tail -12 "$t/out0.txt"; }
# A deploy app with no version fails the schema and the build.
python3 - "$t" <<'P' && ok || bad "a deploy without a version must fail the schema check and the build"
import json, subprocess, sys, pathlib
t = pathlib.Path(sys.argv[1]); m = json.loads((t / 'app/scripts/paste_bundles.json').read_text())
del m['bundles'][0]['apps'][1]['version']; (t / 'nover').mkdir(); 
import shutil; shutil.copytree(t / 'app', t / 'nover/app'); (t / 'nover/app/scripts/paste_bundles.json').write_text(json.dumps(m))
a = subprocess.run([sys.executable, 'scripts/check_manifest.py', str(t / 'nover/app/scripts/paste_bundles.json')], capture_output=True, text=True)
b = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'nover/app')], capture_output=True, text=True)
sys.exit(0 if a.returncode == 1 and 'version' in a.stdout and b.returncode != 0 and 'a deploy needs a version' in b.stderr else 1)
P

# 2. Same version again: the record says it is installed.
round 2
grep -q "^Step 1 of 3: T01 Sample check r1" "$t/out.txt" && ! grep -q "^Step .*T04 Sample optional" "$t/out.txt" && ok || bad "item 3: with every default step done, a run is a repair: every default step is on and the optional step stays off"
grep -q "^Mode: deploy, version 1.0.0 is installed" "$t/out.txt" && [ "$(js)" = "rade-installed/1 1 1.0.0 1.0.0 PASSED" ] && ok || bad "deploy 2: installed text ($(js))"

# Step contract (docs/engine.md): inputs as environment variables, MADE lines and "makes" in the record.
grep -q "contract=1 mode=deploy version=1.0.0 installed=1.0.0 last=PASSED site=True" "$t/out.txt" && grep -q "contract=1 mode=deploy version=1.0.0 installed= last= site=True" "$t/out0.txt" && ok || { bad "contract: step inputs"; grep "contract=" "$t/out.txt" "$t/out0.txt"; }
python3 - "$inst" <<'P' && ok || { bad "contract: steps and made lists in the record"; cat "$inst"; }
import json, sys
s = json.load(open(sys.argv[1]))['apps']['SampleApp/Sample app (deploy)']['steps']
a, b = s['T01 Sample check r1'], s['T02 Sample import r1']
assert a['state'] == 'PASSED' and a['version'] == '1.0.0' and a['made'] == [{'kind': 'file', 'name': 'SAMPLE-T01-result-r1.txt'}, {'kind': 'list', 'name': 'Sample FAIL list at <SITE> and <SITE> and <SITE> for <DODID>'}], a
assert b['state'] == 'PASSED' and b['made'] == [{'kind': 'flow', 'name': 'Sample flow'}], b
P
! grep -rq "fake.example\|sites/fake\|test1234" "$inst" "$od/RADE/SampleApp/Rounds" && ! grep -v "^Working folder: " "$t/out.txt" | grep -q "fake.example\|sites/fake\|test1234" && ok || bad "contract: a site address or the ID reached the record, the report or the screen log"
grep -q "^    MADE backup of nothing (prose, not a record)" "$t/out.txt" && grep -q "^  Result: PASSED (1 passed, 0 failed" "$t/out.txt" && ok || { bad "contract: a MADE name with FAIL changed the counts, or a prose line was taken as a record"; grep "Result:" "$t/out.txt"; }

# 3. A test round: the draft path is unchanged and the record is not touched.
cp "$inst" "$t/inst.before"; round 1
grep -q "Outlook draft could not be created" "$t/out.txt" && ! grep -q "^Mode: deploy" "$t/out.txt" && cmp -s "$inst" "$t/inst.before" && ok || { bad "test round: draft path or record changed"; tail -15 "$t/out.txt"; }

# 4. A newer version whose step fails: lastRun changes, installed stays 1.0.0.
sed -i 's/"version": "1.0.0"/"version": "1.1.0"/' "$t/app/scripts/paste_bundles.json"; echo "Write-Output 'FAIL sample check: forced by the test'" >> "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"
build; round 2
grep -q "^Mode: deploy, version 1.1.0 (installed now: 1.0.0)" "$t/out.txt" && grep -q "^Note: one or more items need review.*Nothing was sent\.$" "$t/out.txt" && grep -q "^For help, ask in the Teams channel RHOPE-OPS\.$" "$t/out.txt" && [ "$(js)" = "rade-installed/1 1 1.0.0 1.1.0 NEEDS REVIEW" ] && ok || { bad "deploy 4: failed upgrade ($(js))"; tail -15 "$t/out.txt"; }

# 5. A damaged record is kept as .damaged and replaced by a valid file.
echo '{ not json' > "$inst"; round 2
[ -f "$inst.damaged" ] && [ "$(js)" = "rade-installed/1 1 None 1.1.0 NEEDS REVIEW" ] && ok || bad "deploy 5: damaged record ($(js))"

# 6. Item 3: the failed step is fixed; the next run does only that step and the version becomes installed.
sed -i '/forced by the test/d' "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"; build; round 2
sed -i 's/"version": "1.1.0"/"version": "1.2.0"/' "$t/app/scripts/paste_bundles.json"; echo "Write-Output 'FAIL sample check: forced by the test'" >> "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"; build; round 2
sed -i '/forced by the test/d' "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"; build; round 2
grep -q "^Step 1 of 1: T01 Sample check r1" "$t/out.txt" && [ "$(js)" = "rade-installed/1 1 1.2.0 1.2.0 PASSED" ] && ok || { bad "item 3: resume after a failed step ($(js))"; grep "^Step \|Result" "$t/out.txt"; }

# Item 3, automatic first: in a deploy, a script step after a hand step must need it ("after"); else the build fails.
python3 - "$t" <<'P' && ok || bad "item 3: a deploy with an automatic step after a hand step it does not need must fail the build"
import json, subprocess, sys, pathlib, shutil
t = pathlib.Path(sys.argv[1]); shutil.copytree(t / 'app', t / 'order/app')
p = t / 'order/app/scripts/paste_bundles.json'; m = json.loads(p.read_text())
del m['bundles'][0]['steps'][3]['after']; p.write_text(json.dumps(m))
a = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'order/app')], capture_output=True, text=True)
m['bundles'][0]['steps'][3]['after'] = ['T09 no such step']; p.write_text(json.dumps(m))
b = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'order/app')], capture_output=True, text=True)
sys.exit(0 if a.returncode != 0 and 'comes after the hand step' in a.stderr and b.returncode != 0 and 'not an earlier step of this app' in b.stderr else 1)
P

# The tagline (the Administrator, 14 Nov 26): no "DoD".
! grep -q "for your DoD organization" engine/rade_build.py && grep -q "'Test and deploy apps for your organization'" engine/rade_build.py && ok || bad "tagline"
echo "ENGINE pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
