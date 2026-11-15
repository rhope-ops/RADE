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
build() { python3 engine/rade_build.py --app-root "$t/app" > "$t/build.txt" 2>&1 || { cat "$t/build.txt"; return 1; }
  sed -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$t/u'#" -e "s#^\$goUrl = '.*'#\$goUrl = 'file://$t/go.md'#" -e "s#\$checkGate = \$true#\$checkGate = \$false#" \
    -e "s#https://example-org.github.io/sample-app#file://$t/go.md#g" -e "s#https://example.invalid/import#file://$t/go.md#" "$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" > "$t/b.ps1"; }
# $1 = the number typed on the Choose question (1 = test app, 2 = deploy app); the other questions get Enter.
round() { printf '%s\n\n\n\n' "$1" | USERPROFILE="$t/u/test1234" pwsh -NoProfile -File "$t/b.ps1" > "$t/out.txt" 2>&1; }
js() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); a=d['apps']['SampleApp/Sample app (deploy)']; print(d['schema'], len(d['apps']), (a['installed'] or {}).get('version'), a['lastRun']['version'], a['lastRun']['state'])" "$inst" 2>&1; }

build && ok || bad "build of the sample bundle"
b="$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1"
grep -q "Name = 'Sample app (deploy)'.*Mode = 'deploy'; Version = '1.0.0'" "$b" && ! grep "Name = 'Sample app (deploy)'" "$b" | grep -q "'outlook'" && ok || bad "catalog: deploy app has Mode, Version and no outlook check"
grep "Name = 'Sample app'" "$b" | grep -q "'outlook'.*Mode = 'test'; Version = ''" && ok || bad "catalog: test app keeps the outlook check and Mode test"

# 1. First deploy: every step on, PASSED, version recorded, nothing sent.
round 2
grep -q "^Mode: deploy, version 1.0.0 (not installed yet)" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && ok || { bad "deploy 1: report has the mode line"; tail -30 "$t/out.txt"; }
grep -q "^Version 1.0.0 of Sample app (deploy) is recorded as installed" "$t/out.txt" && grep -q "^DONE in .*Nothing was sent\.$" "$t/out.txt" && ok || bad "deploy 1: DONE line says nothing was sent"
! grep -qi "outlook\|e-mail\|draft\|Summary copied" "$t/out.txt" && ok || { bad "deploy 1: output names Outlook, an e-mail, a draft or a copied summary"; grep -i "outlook\|e-mail\|draft\|Summary copied" "$t/out.txt"; }
[ ! -e "$cfg/rade-mail-to.txt" ] && ok || bad "deploy 1: an e-mail address file was written"
[ "$(js)" = "rade-installed/1 1 1.0.0 1.0.0 PASSED" ] && ! grep -q "test1234\|$t" "$inst" && ok || { bad "deploy 1: rade-installed.json ($(js))"; cat "$inst"; }

# 2. Same version again: the record says it is installed.
round 2
grep -q "^Mode: deploy, version 1.0.0 is installed" "$t/out.txt" && [ "$(js)" = "rade-installed/1 1 1.0.0 1.0.0 PASSED" ] && ok || bad "deploy 2: installed text ($(js))"

# 3. A test round: the draft path is unchanged and the record is not touched.
cp "$inst" "$t/inst.before"; round 1
grep -q "Outlook draft could not be created" "$t/out.txt" && ! grep -q "^Mode: deploy" "$t/out.txt" && cmp -s "$inst" "$t/inst.before" && ok || { bad "test round: draft path or record changed"; tail -15 "$t/out.txt"; }

# 4. A newer version whose step fails: lastRun changes, installed stays 1.0.0.
sed -i 's/"version": "1.0.0"/"version": "1.1.0"/' "$t/app/scripts/paste_bundles.json"; echo "Write-Output 'FAIL sample check: forced by the test'" >> "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"
build; round 2
grep -q "^Mode: deploy, version 1.1.0 (installed now: 1.0.0)" "$t/out.txt" && grep -q "^Note: one or more items need review.*Nothing was sent\.$" "$t/out.txt" && [ "$(js)" = "rade-installed/1 1 1.0.0 1.1.0 NEEDS REVIEW" ] && ok || { bad "deploy 4: failed upgrade ($(js))"; tail -15 "$t/out.txt"; }

# 5. A damaged record is kept as .damaged and replaced by a valid file.
echo '{ not json' > "$inst"; round 2
[ -f "$inst.damaged" ] && [ "$(js)" = "rade-installed/1 1 None 1.1.0 NEEDS REVIEW" ] && ok || bad "deploy 5: damaged record ($(js))"

# The tagline (the Administrator, 14 Nov 26): no "DoD".
! grep -q "for your DoD organization" engine/rade_build.py && grep -q "'Test and deploy apps for your organization'" engine/rade_build.py && ok || bad "tagline"
echo "ENGINE pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
