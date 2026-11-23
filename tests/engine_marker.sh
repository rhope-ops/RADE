# RADE engine tests, part of tests/engine_test.sh (sourced there, never run alone; split out of engine_test.sh on
# 2026-11-23 to keep each file at 450 lines or fewer, fleet v2 DEC 6). Uses what engine_test.sh defined before it: $t,
# ok, bad, go, psrun, swap, rec and the built sample in $t/app. Guardrails 3 and 4 (site rights and the install record on
# the site, with the fake PnP of tests/fake-pnp): the build checks of the marker manifest, then groups MA, MC, MD and MG;
# the shared-file helpers sha and valid (engine_test.sh uses them after this file too); and the cross-version runs
# (group X). Each group runs in the background; engine_test.sh "gather" waits for them and adds their counts.
# Network: none, except one git fetch of the engine-v1 commit from origin when this clone does not hold it (group X).
# Writes: only under $t (the temporary folder of tests/engine_test.sh).
# Credentials: none.
# ---- Guardrails 3 and 4 (the Administrator, 14 Nov 26; docs/engine.md "Guardrails"; 1 and 2: tests/engine_test.sh, after this file).
# 3 and 4. Site rights with the admin flag (shown only), and the install record on the site (fake PnP: tests/fake-pnp).
# The marker app is the sample at version 1.2.0, as the text-mode deploys below leave it (it was built after them until 2026-11-17).
python3 - "$t" <<'P' && ok || bad "marker: build of the marker manifest"
import json, subprocess, sys, pathlib, shutil
t = pathlib.Path(sys.argv[1]); shutil.copytree(t / 'app', t / 'mk/app')
p = t / 'mk/app/scripts/paste_bundles.json'; m = json.loads(p.read_text().replace('"version": "1.0.0"', '"version": "1.2.0"')); b = m['bundles'][0]
b['apps'][1]['marker'] = {'list': 'Sample Settings', 'key': 'InstalledVersion', 'field': 'SettingValue'}
p.write_text(json.dumps(m))
r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'mk/app')], capture_output=True, text=True)
assert r.returncode != 0 and 'a marker needs mode deploy and a step that needs site-rights' in (r.stdout + r.stderr), r.stdout + r.stderr
b['steps'][0]['needs'] = ['ps', 'site-rights']; p.write_text(json.dumps(m))
r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'mk/app')], capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
for bad in (['CON'], ['Tasks', 'tasks'], ['Tasks ']):   # backup: a name Windows reserves, a clash in letter case, a trailing space
    b['apps'][1]['backup'] = bad; p.write_text(json.dumps(m))
    r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'mk/app')], capture_output=True, text=True)
    assert r.returncode != 0 and 'backup: unique plain titles' in (r.stdout + r.stderr), (bad, r.stdout + r.stderr)
# (engine-v31) a title with parentheses builds (R39); restore needs backup and plain test-site names (or "local"); a good one is in the bundle.
def build(): return subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'mk/app')], capture_output=True, text=True)
b['apps'][1]['backup'] = ['Tasks', 'Recs (Form 1)']; p.write_text(json.dumps(m)); r = build(); assert r.returncode == 0, r.stdout + r.stderr
b['apps'][1]['restore'] = {'testSites': ['https://x']}; p.write_text(json.dumps(m)); r = build()
assert r.returncode != 0 and 'restore.testSites' in (r.stdout + r.stderr), r.stdout + r.stderr
b['apps'][1]['restore'] = {'testSites': ['sample-test'], 'pause': {'list': 'Sample Settings', 'title': 'RestorePause', 'field': 'SettingValue', 'on': 'On'}}
p.write_text(json.dumps(m)); r = build(); assert r.returncode == 0, r.stdout + r.stderr
assert subprocess.run([sys.executable, 'scripts/check_manifest.py', str(p)], capture_output=True, text=True).returncode == 0
bun = ''.join(x.read_text(encoding='utf-8-sig') for x in (t / 'mk/app').rglob('*.ps1') if 'Restore = @{ TestSites' in x.read_text(encoding='utf-8-sig'))
assert ("Backup = @('Tasks', 'Recs (Form 1)'); Restore = @{ TestSites = @('sample-test'); Local = $false; "
        "Pause = @{ List = 'Sample Settings'; Title = 'RestorePause'; Field = 'SettingValue'; On = 'On' } }") in bun, 'restore: not in the bundle'
# (engine-v32) "testSites": "local" builds with no site name in the bundle; another word is refused by the build and the schema.
b['apps'][1]['restore'] = {'testSites': 'local', 'pause': {'list': 'Sample Settings', 'title': 'RestorePause', 'field': 'SettingValue', 'on': 'On'}}
p.write_text(json.dumps(m)); r = build(); assert r.returncode == 0, r.stdout + r.stderr
assert subprocess.run([sys.executable, 'scripts/check_manifest.py', str(p)], capture_output=True, text=True).returncode == 0
bun = ''.join(x.read_text(encoding='utf-8-sig') for x in (t / 'mk/app').rglob('*.ps1') if 'Restore = @{ TestSites' in x.read_text(encoding='utf-8-sig'))
assert "Restore = @{ TestSites = @(); Local = $true; Pause = @{" in bun, 'restore local: not in the bundle'
b['apps'][1]['restore'] = {'testSites': 'sample-test'}; p.write_text(json.dumps(m)); r = build()
assert r.returncode != 0 and 'restore.testSites' in (r.stdout + r.stderr), r.stdout + r.stderr
assert subprocess.run([sys.executable, 'scripts/check_manifest.py', str(p)], capture_output=True, text=True).returncode != 0, 'schema: testSites must be a list or "local"'
b['apps'][1]['restore'] = {'testSites': ['sample-test']}; p.write_text(json.dumps(m))
del b['apps'][1]['backup']; p.write_text(json.dumps(m)); r = build()
assert r.returncode != 0 and 'restore needs backup' in (r.stdout + r.stderr), r.stdout + r.stderr
del b['apps'][1]['restore']; p.write_text(json.dumps(m))
r = subprocess.run([sys.executable, 'scripts/check_manifest.py', str(p)], capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
P
fake="$t/fake.json"; mods="$PWD/tests/fake-pnp"
# mkround NAME: runs the marker bundle as the deploy app with the fake PnP, as the user of the users root $t/NAME.
mkround() { # $1 = users root name; runs the marker bundle as the deploy app with the fake PnP
  mkdir -p "$t/$1/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config";
    echo "https://usaf.dps.mil/sites/fake" > "$t/$1/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
  swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-$1.ps1" "$t/$1"
  psrun "$t/m-$1.ps1" "$t/out-$1.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/$1/test1234"; }
go MA; {   # group MA: runs in the background (see "go" above)
fake="$t/fake-ma.json"
echo '{ "admin": false, "rights": true, "list": true, "rows": {} }' > "$fake"; mkround m1
grep -q "PASSED: You can change the site.*Site collection administrator: no (shown only, not required)" "$t/out-m1.txt" && ok || { bad "rights: admin flag shown, not required";
  grep "change the site" "$t/out-m1.txt"; }
grep -q '^On the site   after the steps, one row in the list "Sample Settings"' "$t/out-m1.txt" &&
  grep -q "^First install from this account. Install Sample app (deploy) once for each wing" "$t/out-m1.txt" && ok || bad "marker: the plan names the row and gives the one-install notice"
grep -q '^Install record on the site: "Sample Settings", row "InstalledVersion" now holds version [0-9.]* and the date (added)' "$t/out-m1.txt" &&
  grep -q '"InstalledVersion": *"[0-9.]* 20[0-9-]*"' "$fake" && ok || { bad "marker: written after a whole install"; tail -5 "$t/out-m1.txt"; cat "$fake"; }
# Another account (no record of its own) on the same site: the check fails. The installer's own second run passes.
mkround m2
grep -q "FAILED: You can change the site.*This site already has an install of this application \[version [0-9.]*\], made from another account" "$t/out-m2.txt" && ok ||
  { bad "marker: a second account is stopped"; grep "change the site" "$t/out-m2.txt"; }
mkdir -p "$t/m4/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config";
  echo "https://usaf.dps.mil/sites/fake" > "$t/m4/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-m4.ps1" "$t/m4"; sed -i 's#\$checkGate = \$false#$checkGate = $true#' "$t/m-m4.ps1"   # a third account, with the gate on
psrun "$t/m-m4.ps1" "$t/out-m4.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m4/test1234"
grep -q "^You cannot deploy yet" "$t/out-m4.txt" && ! grep -q "^Step 1 of" "$t/out-m4.txt" && [ ! -e "$t/m4/test1234/OneDrive - United States Air Force/RADE/Config/installed" ] && ok ||
  { bad "marker: with the gate on, another account runs no step"; tail -12 "$t/out-m4.txt"; }
mkround m1
grep -q "PASSED: You can change the site" "$t/out-m1.txt" && ! grep -q "^First install from this account" "$t/out-m1.txt" && ok || { bad "marker: the installer's own second run passes";
  grep "change the site" "$t/out-m1.txt"; }
echo '{ "admin": true, "rights": true, "list": false, "rows": {} }' > "$fake"; mkround m3
grep -q "Site collection administrator: yes" "$t/out-m3.txt" &&
  grep -q '^NOTE: the install record on the site ("Sample Settings", row "InstalledVersion") was not written: the list was not found' "$t/out-m3.txt" && ok ||
  { bad "marker: a missing list gives a NOTE"; tail -5 "$t/out-m3.txt"; }

# Review, 14 Nov 26. The installer on another site that has a row is stopped too (the record is per site).
echo '{ "admin": false, "rights": true, "list": true, "rows": { "InstalledVersion": "9.9 2026-01-01" } }' > "$fake"
echo "https://usaf.dps.mil/sites/other" > "$t/m1/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
psrun "$t/m-m1.ps1" "$t/out-m1b.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m1/test1234"
grep -q "FAILED: You can change the site.*\[version 9.9\], made from another account or for another site" "$t/out-m1b.txt" && ok || { bad "marker: the installer is stopped on another site";
  grep "change the site" "$t/out-m1b.txt"; }
echo "GROUP $pass $fail"; } > "$t/grp-MA.log" 2>&1 &
go MC; {   # group MC: runs in the background (see "go" above)
fake="$t/fake-mc.json"
# A row value that is not a version still counts as an install; a list that cannot be read is FAILED.
echo '{ "admin": false, "rights": true, "list": true, "rows": { "InstalledVersion": "v9.9 someday" } }' > "$fake"; mkround m5
grep -q "FAILED: You can change the site.*\[version not readable\]" "$t/out-m5.txt" && ok || { bad "marker: any row value is an install"; grep "change the site" "$t/out-m5.txt"; }
echo '{ "admin": false, "rights": true, "list": true, "listError": true, "rows": {} }' > "$fake"; mkround m7
grep -q "FAILED: You can change the site.*The install record on the site could not be read" "$t/out-m7.txt" && ok || { bad "marker: an unreadable record fails closed";
  grep "change the site" "$t/out-m7.txt"; }
echo "GROUP $pass $fail"; } > "$t/grp-MC.log" 2>&1 &
go MD; {   # group MD: runs in the background (see "go" above)
fake="$t/fake-md.json"
# A part install (one step skipped) writes the row marked partial; that account's next run is not stopped; the row is then updated.
echo '{ "admin": false, "rights": true, "list": true, "rows": {} }' > "$fake"
mkdir -p "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config";
  echo "https://usaf.dps.mil/sites/fake" > "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-m6.ps1" "$t/m6"
psrun "$t/m-m6.ps1" "$t/out-m6.txt" $'2\n\nS\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "marked partial (added)" "$t/out-m6.txt" && grep -q '"InstalledVersion": *"[0-9.]* 20[0-9-]* partial"' "$fake" && ok || { bad "marker: a part install is recorded as partial";
  tail -4 "$t/out-m6.txt"; cat "$fake"; }
mkround m6
grep -q "PASSED: You can change the site" "$t/out-m6.txt" && grep -q "now holds version [0-9.]* and the date (updated)" "$t/out-m6.txt" && ! grep -q "partial" "$fake" && ok ||
  { bad "marker: the same account finishes its part install"; grep "change the site\|Install record" "$t/out-m6.txt"; cat "$fake"; }

# Second review, 14 Nov 26. A run that reached no step (failed download) does not make the account "installed here":
# after another account's install it is stopped, with the gate on, and the row stays.
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": {} }' > "$fake"
mkdir -p "$t/m8/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config";
  echo "https://usaf.dps.mil/sites/fake" > "$t/m8/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-m8.ps1" "$t/m8"; sed "s#file://$t/app/flow/SAMPLE-data#file://$t/app/flow/NOPE#" "$t/m-m8.ps1" > "$t/m-m8f.ps1"
psrun "$t/m-m8f.ps1" "$t/out-m8f.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m8/test1234"
grep -q "so no step ran" "$t/out-m8f.txt" && ! grep -q "InstalledVersion" "$fake" && ok || { bad "marker: a run with no step writes no row"; tail -4 "$t/out-m8f.txt"; }
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": { "InstalledVersion": "7.7 2026-01-01" } }' > "$fake"
sed -i 's#\$checkGate = \$false#$checkGate = $true#' "$t/m-m8.ps1"
psrun "$t/m-m8.ps1" "$t/out-m8.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m8/test1234"
grep -q "FAILED: You can change the site.*\[version 7.7\]" "$t/out-m8.txt" && ! grep -q "^Step 1 of" "$t/out-m8.txt" && grep -q '"7.7 2026-01-01"' "$fake" && ok ||
  { bad "marker: a no-step run does not make the account the installer"; grep "change the site\|^Step" "$t/out-m8.txt"; cat "$fake"; }
# Step records from one site do not count on another: account m6 (whole install on site "fake") on a new, empty site
# is a first install again and runs every needed step.
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": {} }' > "$fake"
echo "https://usaf.dps.mil/sites/second" > "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
psrun "$t/m-m6.ps1" "$t/out-m6b.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "^First install from this account" "$t/out-m6b.txt" && grep -q "^Step 1 of [0-9]: T01 Sample check r1" "$t/out-m6b.txt" && grep -q "and the date (added)" "$t/out-m6b.txt" && ok ||
  { bad "marker: records from another site do not count"; grep "^First\|^Step\|Install record" "$t/out-m6b.txt"; }
# A part install on a third site, then its second run: the step that never ran there (T03) runs; only then is the row whole.
echo "https://usaf.dps.mil/sites/third" > "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
psrun "$t/m-m6.ps1" "$t/out-m6c.txt" $'2\n\nS\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "marked partial" "$t/out-m6c.txt" && ! grep -q "T03 Sample verify r1: PASSED" "$t/out-m6c.txt" && ok || { bad "marker: part install on a third site";
  grep "T03\|Install record" "$t/out-m6c.txt"; }
psrun "$t/m-m6.ps1" "$t/out-m6d.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "^Step [0-9] of [0-9]: T03 Sample verify r1" "$t/out-m6d.txt" && grep -q "is recorded as installed" "$t/out-m6d.txt" && ! grep -q "partial" "$fake" && ok ||
  { bad "marker: a step that never ran on this site must run before the install is whole"; grep "^Step\|installed\|Install record" "$t/out-m6d.txt"; }
python3 - "$t/m6/test1234/OneDrive - United States Air Force/RADE/Config/installed" <<'P' && ok || bad "record: one file for each site, keyed by a hash, no address"
import json, sys, re, pathlib, hashlib
fs = sorted(pathlib.Path(sys.argv[1]).iterdir()); raw = [f.read_text() for f in fs]; keys = [json.loads(r)['key'] for r in raw]
assert len(keys) == 3 and all(re.fullmatch(r'SampleApp/Sample app \(deploy\)@[0-9a-f]{12}', k) for k in keys), keys
assert all(f.name == hashlib.sha256(k.lower().encode()).hexdigest()[:12] + '.json' for f, k in zip(fs, keys)), fs
assert not any('usaf.dps.mil' in r for r in raw)
P
echo "GROUP $pass $fail"; } > "$t/grp-MD.log" 2>&1 &
go MG; {   # group MG: runs in the background (see "go" above)
fake="$t/fake-mg.json"
# The site row is not written when the account's own record cannot be saved (it would stop that account's next run).
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": {} }' > "$fake"
mkdir -p "$t/m9/test1234/OneDrive - United States Air Force/RADE/Config"; : > "$t/m9/test1234/OneDrive - United States Air Force/RADE/Config/installed"; mkround m9
grep -q "installed-version record (RADE.Config.installed) could not be saved" "$t/out-m9.txt" && ! grep -q "^Install record on the site" "$t/out-m9.txt" && ! grep -q "InstalledVersion" "$fake" &&
  ok || { bad "marker: no row when the own record failed"; grep "record" "$t/out-m9.txt"; cat "$fake"; }
echo "GROUP $pass $fail"; } > "$t/grp-MG.log" 2>&1 &
# Shared-file helpers (groups X and S): sha FILE... gives the SHA-256 of each file; valid SCHEMA FILE checks FILE against SCHEMA.
sha() { sha256sum "$@" | cut -c1-64 | tr '\n' ' '; }
# valid SCHEMA FILE: checks FILE against the JSON schema SCHEMA; prints each error and ends with 1 when there is one.
valid() { python3 - "$1" "$2" <<'P'
import json, sys
from jsonschema import Draft202012Validator
s = json.load(open(sys.argv[1])); Draft202012Validator.check_schema(s)
e = sorted(Draft202012Validator(s).iter_errors(json.load(open(sys.argv[2]))), key=str)
for x in e: print('  schema:', '/'.join(str(p) for p in x.path), x.message[:160])
sys.exit(1 if e else 0)
P
}
go X; {   # group X: runs in the background (see "go" above)
# Cross-version: the engine in the field (engine-v1) and this engine on one computer. Run this engine, then v1, then this
# engine. The two keep their records in different files, so the first check shows that v1 really ran a deploy on the same
# folder and left this engine's file alone; the second can fail: this engine reads the saved checks that v1 wrote.
# Not tested here: a record that cannot be read while another program holds it (no such lock on Linux).
v1=ba1b64e1a728c7aea0ab9b4ff53890e7c34c8151   # tag engine-v1: the engine in rhope-ops/90-161.Z scripts/rade.lock.json on 2026-11-15
git cat-file -e "$v1^{commit}" 2>/dev/null || git fetch -q origin "$v1" 2>/dev/null
mkdir -p "$t/v1/engine" "$t/v1/assets/logo" "$t/xv/app/scripts"
if git show "$v1:engine/rade_build.py" > "$t/v1/engine/rade_build.py" 2>/dev/null && git show "$v1:assets/logo/logo-K-128.png" > "$t/v1/assets/logo/logo-K-128.png" 2>/dev/null; then
  cp -r tests/fixture-app/. "$t/xv/app/"; cp schemas/examples/sample-manifest.json "$t/xv/app/scripts/paste_bundles.json"
  xo="$t/xu/test1234/OneDrive - United States Air Force"; mkdir -p "$xo/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$xo/RADE/SampleApp/Config/SAMPLE-site.txt"
  xb="$t/xv/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1"; xi="$xo/RADE/Config/installed/$(rec 'SampleApp/Sample app (deploy)')"
  # xrun BUNDLE OUT: runs the bundle BUNDLE as the deploy app (answers 2 and Enter) as the cross-version user; OUT gets its output.
  xrun() { psrun "$1" "$2" $'2\n\n\n\n' USERPROFILE="$t/xu/test1234"; }
  python3 engine/rade_build.py --app-root "$t/xv/app" > /dev/null 2>&1 && swap "$xb" "$t/x-new.ps1" "$t/xu"
  python3 "$t/v1/engine/rade_build.py" --app-root "$t/xv/app" > /dev/null 2>&1 && swap "$xb" "$t/x-v1.ps1" "$t/xu"
  xrun "$t/x-new.ps1" "$t/x1.txt"; h0=$(sha "$xi"); n0=$(ls "$xo/RADE/Config/installed" | wc -l)
  xrun "$t/x-v1.ps1" "$t/x2.txt"; h1=$(sha "$xi"); n1=$(ls "$xo/RADE/Config/installed" | wc -l)
  xrun "$t/x-new.ps1" "$t/x3.txt"
  ! cmp -s "$t/x-new.ps1" "$t/x-v1.ps1" && grep -q "is recorded as installed" "$t/x1.txt" && grep -q "is recorded as installed" "$t/x2.txt" && [ -f "$xo/RADE/Config/rade-installed.json" ] &&
    [ "$h0" = "$h1" ] && [ "$n0$n1" = 11 ] && ok || { bad "cross-version: engine-v1 changed this engine's record ($n0 $n1)"; tail -3 "$t/x2.txt"; }
  grep -q "^Mode: deploy, version 1.0.0 is installed" "$t/x3.txt" && valid schemas/rade-installed.schema.json "$xi" && valid schemas/rade-checks.schema.json "$xo/RADE/Config/rade-checks.json" && ok ||
    { bad "cross-version: this engine after engine-v1 (its record, the saved checks)"; grep "^Mode" "$t/x3.txt"; }
  # Saved checks (docs/engine.md "Results"): a slow check is reused; the fast checks ps and child run fresh (from engine-v21).
  grep -q "PASSED: Your OneDrive folder is set up. Last check: " "$t/x3.txt" && ok || bad "saved checks: the OneDrive check is not reused"
  grep -q "PASSED: PowerShell is version 5.1 or newer. Version \[" "$t/x3.txt" && ok || bad "saved checks: the ps check did not run fresh"
  grep -q "PASSED: RADE can run its scripts. Test script ran" "$t/x3.txt" && ok || bad "saved checks: the child check did not run fresh"
else bad "cross-version: the engine-v1 commit $v1 is not in this clone and could not be fetched (git fetch origin $v1)"; fi
echo "GROUP $pass $fail"; } > "$t/grp-X.log" 2>&1 &
