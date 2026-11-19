#!/usr/bin/env bash
# RADE engine tests (run by scripts/check.local.sh). Pass = last line "ENGINE pass=N fail=0".
# Builds the sample manifest (schemas/examples/sample-manifest.json + tests/fixture-app) into a bundle and runs it in
# pwsh text mode, with C:\Users swapped for a temp root. Linux has no Windows Forms: the window's logic runs against
# stand-in types with a scripted user (section "window": tests/engine_window.sh); what the window looks like is not tested here.
# Covers deploy v1 (docs/engine.md): a deploy sends nothing and keeps one record file for each app in RADE\Config\installed (docs/engine.md "Shared files"); a test round is unchanged.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
engine_src="engine/rade_build.py $(ls engine/ps/*.ps1 engine/ps/window/*.ps1 | tr '\n' ' ')"   # the build file and its PowerShell parts (docs/code-standard.md C10)
pass=0; fail=0
# Every run below gets this variable, as a RADE started from its shortcut has it on Windows (-ExecutionPolicy Bypass hands
# it down). The child check's probe must take it out: its line "without Bypass [ran]" below fails if it does not.
export PSExecutionPolicyPreference=Bypass
ok() { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
# Groups (bloat audit P8, 2026-11-16): a section whose runs use only their own folders runs in the background, between
# "go NAME; {" and "} > ... &". The subshell starts from the counts at that point; "GROUP" in its log is its own part.
# gather waits for all groups, prints each log in file order and adds the counts (a group with no GROUP line failed).
groups=(); base=()
go() { groups+=("$1"); base+=("$pass $fail"); }
gather() { wait; local i g c b; for i in "${!groups[@]}"; do g=${groups[$i]}; c=$(grep '^GROUP ' "$t/grp-$g.log" | tail -1); grep -v '^GROUP ' "$t/grp-$g.log"
  if [ -z "$c" ]; then bad "group $g ended before its last line"; else set -- $c ${base[$i]}; pass=$((pass + $2 - $4)); fail=$((fail + $3 - $5)); fi; done; }
command -v pwsh >/dev/null || { echo "FAIL pwsh is missing (PowerShell 7: see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)"; echo "ENGINE pass=0 fail=1"; exit 1; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
od="$t/u/test1234/OneDrive - United States Air Force"; cfg="$od/RADE/Config"
# rec KEY: the record file name of one app (the first 12 hex of the SHA-256 of the lower-case key), as the engine names it.
rec() { python3 -c "import hashlib,sys; print(hashlib.sha256(sys.argv[1].lower().rstrip('/').encode()).hexdigest()[:12] + '.json')" "$1"; }
inst="$cfg/installed/$(rec 'SampleApp/Sample app (deploy)')"
# ans FILE: the sample manifest gets what tests/fixture-app/answers.json holds: titles, and for the hand step T02 its questions
# (manifest "answers"), a note and a guide with one line that has no number.
ans() { python3 - "$1" <<'P'
import json, sys
p = sys.argv[1]; m = json.load(open(p)); a = json.load(open('tests/fixture-app/answers.json'))
for s in m['bundles'][0]['steps']:
    if s['name'] in a['titles']: s['title'] = a['titles'][s['name']]
    if s['name'] == a['step']: s['answers'] = a['answers']; s.update(a['set'])
json.dump(m, open(p, 'w'), indent=2)
P
}
mkdir -p "$od" "$t/app/scripts"; cp -r tests/fixture-app/. "$t/app/"; cp schemas/examples/sample-manifest.json "$t/app/scripts/paste_bundles.json"; ans "$t/app/scripts/paste_bundles.json"
# The sample's application logo (application.logo): RADE's own 64 px logo, copied into the temporary app so no PNG is kept in tests/.
mkdir -p "$t/app/assets"; cp assets/logo/logo-rho-64.png "$t/app/assets/sample-logo.png"
python3 -c "import json,sys; p=sys.argv[1]; m=json.load(open(p)); m['application']['logo']='assets/sample-logo.png'; json.dump(m,open(p,'w'),indent=2)" "$t/app/scripts/paste_bundles.json"
: > "$t/go.md"; echo '{ "apps": { "Sample app (deploy)": "9.0.0", "Sample app": "9.0.0" } }' > "$t/rel.json"
mkdir -p "$od/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$od/RADE/SampleApp/Config/SAMPLE-site.txt"
# swap IN OUT USERS: the test copy of a bundle: users root, repository addresses and the check gate swapped for local ones,
# and the computer's full name read from RADE_TEST_FQDN (default: a fake NIPR name; the engine itself has no such switch).
swap() { sed -e 's#^function Get-OwnFqdn .*#function Get-OwnFqdn { if ($null -ne $env:RADE_TEST_FQDN) { return $env:RADE_TEST_FQDN }; return '"'pc01.area52.example.invalid'"' }#' -e "s#^\$usersRoot = 'C:\\\\Users'#\$usersRoot = '$3'#" -e "s#^\$goUrl = '.*'#\$goUrl = 'file://$t/go.md'#" -e "s#^\$releaseUrl = '.*'#\$releaseUrl = 'file://$t/rel.json'#" -e "s#\$checkGate = \$true#\$checkGate = \$false#" \
    -e "s#https://raw.githubusercontent.com/example-org/sample-app/v1.0.0/#file://$t/app/#" -e "s#https://example-org.github.io/sample-app#file://$t/go.md#g" -e "s#https://example.invalid/import#file://$t/go.md#" "$1" > "$2"; }
build() { python3 engine/rade_build.py --app-root "$t/app" > "$t/build.txt" 2>&1 || { cat "$t/build.txt"; return 1; }
  swap "$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/b.ps1" "$t/u"; }
# $1 = the number typed on the Choose question (1 = test app, 2 = deploy app); $2 = the answer in the guide step
# (empty = done, S = skip); the other questions get Enter. Not tested here: Windows PowerShell 5.1.
round() { local in; printf -v in '%s\n\n%s\n\n' "$1" "${2:-}"; psrun "$t/b.ps1" "$t/out.txt" "$in" USERPROFILE="$t/u/test1234"; }
# psrun FILE OUT INPUT [NAME=VALUE...]: what "printf %s INPUT | NAME=VALUE pwsh -NoProfile -File FILE > OUT 2>&1" gives,
# with every such run of one group (or of the main part) in one pwsh process: tests/pwsh_batch.ps1. A new pwsh costs about
# 2 s of CPU (profile, 2026-11-16). A run that sets an empty value, and every run with RADE_T_BATCH=0, gets its own process.
psrun() { local f=$1 o=$2 in=$3 rc kv own=0; shift 3
  for kv in "$@"; do [ -z "${kv#*=}" ] && own=1; done
  if [ "$own" = 1 ] || [ "${RADE_T_BATCH:-1}" = 0 ]; then printf '%s' "$in" | env "$@" pwsh -NoProfile -File "$f" > "$o" 2>&1; return; fi
  if [ "${ps_owner:-}" != "$BASHPID" ]; then   # the first run of this group: start its runner
    ps_owner=$BASHPID; mkfifo "$t/rq-$ps_owner" "$t/rs-$ps_owner"   # (in "cmd &" $BASHPID is the new process's)
    pwsh -NoProfile -File tests/pwsh_batch.ps1 "$t/rq-$ps_owner" "$t/rs-$ps_owner" > "$t/batch-$ps_owner.log" 2>&1 &
    ps_pid=$!; exec {ps_rq}<>"$t/rq-$ps_owner" {ps_rs}<>"$t/rs-$ps_owner"   # read-write: an open never waits
  fi
  printf '%s' "$in" > "$t/in-$ps_owner"; : > "$o"   # a stopped runner must not leave the last round's output
  { printf '%s\t%s\t%s' "$f" "$t/in-$ps_owner" "$o"; for kv in "$@"; do printf '\t%s' "$kv"; done; printf '\n'; } >&"$ps_rq"
  until read -r -t 5 rc <&"$ps_rs"; do   # a runner that stopped never answers
    kill -0 "$ps_pid" 2>/dev/null || { echo "psrun: the runner stopped (log: $t/batch-$ps_owner.log)" >> "$o"; cat "$t/batch-$ps_owner.log" >> "$o"; return 1; }
  done
  return "$rc"; }
# psclose: the main part's runner ends (before gather, which waits for every background process).
psclose() { if [ "${ps_owner:-}" = "$BASHPID" ]; then exec {ps_rq}>&- {ps_rs}<&-; kill "$ps_pid" 2>/dev/null; wait "$ps_pid" 2>/dev/null; ps_owner=; fi; }
js() { python3 -c "import json,sys; import glob,os; a=json.load(open(sys.argv[1])); assert a['key']=='SampleApp/Sample app (deploy)'; print(a['schema'], len(glob.glob(os.path.dirname(sys.argv[1])+'/*')), (a['installed'] or {}).get('version'), a['lastRun']['version'], a['lastRun']['state'])" "$inst" 2>&1; }

build && ok || bad "build of the sample bundle"
# application.logo: the bundle carries the logo as base64 text; a missing file or a file that is not a PNG stops the build.
grep -q "^\$appLogoPng = 'iVBORw0KGgo" "$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" && ok || bad "application logo in the bundle"
mv "$t/app/assets/sample-logo.png" "$t/sl.png"; python3 engine/rade_build.py --app-root "$t/app" > "$t/lg.txt" 2>&1; grep -q "application.logo: no file at assets/sample-logo.png" "$t/lg.txt" && ok || bad "build stops on a missing application logo"
echo "not a png" > "$t/app/assets/sample-logo.png"; python3 engine/rade_build.py --app-root "$t/app" > "$t/lg.txt" 2>&1; grep -q "application.logo: not a PNG file" "$t/lg.txt" && ok || bad "build stops on an application logo that is not a PNG"
sed -i 's#"logo": "assets/sample-logo.png"#"logo": "../sample-logo.png"#' "$t/app/scripts/paste_bundles.json"; python3 engine/rade_build.py --app-root "$t/app" > "$t/lg.txt" 2>&1; grep -q "application.logo: the path must stay inside the application repo" "$t/lg.txt" && ok || bad "build stops on an application logo outside the app repo"
for bad in "/etc/sample-logo.png" "assets/../../sample-logo.png"; do sed -i "s#\"logo\": \"[^\"]*\"#\"logo\": \"$bad\"#" "$t/app/scripts/paste_bundles.json"; python3 engine/rade_build.py --app-root "$t/app" > "$t/lg.txt" 2>&1; grep -q "application.logo: the path must stay inside the application repo" "$t/lg.txt" && ok || bad "build stops on application logo $bad"; done
sed -i 's#"logo": "[^"]*"#"logo": "assets/sample-logo.png"#' "$t/app/scripts/paste_bundles.json"
mv "$t/sl.png" "$t/app/assets/sample-logo.png"; build || bad "rebuild after the application logo checks"
b="$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1"
grep -q "Name = 'Sample app (deploy)'.*Mode = 'deploy'; Version = '1.0.0'" "$b" && ! grep "Name = 'Sample app (deploy)'" "$b" | grep -q "'outlook'" && ok || bad "catalog: deploy app has Mode, Version and no outlook check"
grep "Name = 'Sample app'" "$b" | grep -q "'outlook'.*Mode = 'test'; Version = ''" && ok || bad "catalog: test app keeps the outlook check and Mode test"
# Groups that use only their own folders start here, so they run beside the serial text-mode part below (speed audit,
# 2026-11-17): the window (W, W2, W3), the install record on the site (MA, MC, MD, MG) and the cross-version runs (X).
# ---- window: the window runs, in groups W, W2 and W3 (tests/engine_window.sh).
. tests/engine_window.sh
# ---- Guardrails 3 and 4 (the Administrator, 14 Nov 26; docs/engine.md "Guardrails"; 1 and 2 are below).
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
r = subprocess.run([sys.executable, 'scripts/check_manifest.py', str(p)], capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
P
fake="$t/fake.json"; mods="$PWD/tests/fake-pnp"
mkround() { # $1 = users root name; runs the marker bundle as the deploy app with the fake PnP
  mkdir -p "$t/$1/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$t/$1/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
  swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-$1.ps1" "$t/$1"
  psrun "$t/m-$1.ps1" "$t/out-$1.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/$1/test1234"; }
go MA; {   # group MA: runs in the background (see "go" above)
fake="$t/fake-ma.json"
echo '{ "admin": false, "rights": true, "list": true, "rows": {} }' > "$fake"; mkround m1
grep -q "PASSED: You can change the site.*Site collection administrator: no (shown only, not required)" "$t/out-m1.txt" && ok || { bad "rights: admin flag shown, not required"; grep "change the site" "$t/out-m1.txt"; }
grep -q '^On the site   after the steps, one row in the list "Sample Settings"' "$t/out-m1.txt" && grep -q "^First install from this account. Install Sample app (deploy) once for each wing" "$t/out-m1.txt" && ok || bad "marker: the plan names the row and gives the one-install notice"
grep -q '^Install record on the site: "Sample Settings", row "InstalledVersion" now holds version [0-9.]* and the date (added)' "$t/out-m1.txt" && grep -q '"InstalledVersion": *"[0-9.]* 20[0-9-]*"' "$fake" && ok || { bad "marker: written after a whole install"; tail -5 "$t/out-m1.txt"; cat "$fake"; }
# Another account (no record of its own) on the same site: the check fails. The installer's own second run passes.
mkround m2
grep -q "FAILED: You can change the site.*This site already has an install of this application \[version [0-9.]*\], made from another account" "$t/out-m2.txt" && ok || { bad "marker: a second account is stopped"; grep "change the site" "$t/out-m2.txt"; }
mkdir -p "$t/m4/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$t/m4/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-m4.ps1" "$t/m4"; sed -i 's#\$checkGate = \$false#$checkGate = $true#' "$t/m-m4.ps1"   # a third account, with the gate on
psrun "$t/m-m4.ps1" "$t/out-m4.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m4/test1234"
grep -q "^You cannot deploy yet" "$t/out-m4.txt" && ! grep -q "^Step 1 of" "$t/out-m4.txt" && [ ! -e "$t/m4/test1234/OneDrive - United States Air Force/RADE/Config/installed" ] && ok || { bad "marker: with the gate on, another account runs no step"; tail -12 "$t/out-m4.txt"; }
mkround m1
grep -q "PASSED: You can change the site" "$t/out-m1.txt" && ! grep -q "^First install from this account" "$t/out-m1.txt" && ok || { bad "marker: the installer's own second run passes"; grep "change the site" "$t/out-m1.txt"; }
echo '{ "admin": true, "rights": true, "list": false, "rows": {} }' > "$fake"; mkround m3
grep -q "Site collection administrator: yes" "$t/out-m3.txt" && grep -q '^NOTE: the install record on the site ("Sample Settings", row "InstalledVersion") was not written: the list was not found' "$t/out-m3.txt" && ok || { bad "marker: a missing list gives a NOTE"; tail -5 "$t/out-m3.txt"; }

# Review, 14 Nov 26. The installer on another site that has a row is stopped too (the record is per site).
echo '{ "admin": false, "rights": true, "list": true, "rows": { "InstalledVersion": "9.9 2026-01-01" } }' > "$fake"
echo "https://usaf.dps.mil/sites/other" > "$t/m1/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
psrun "$t/m-m1.ps1" "$t/out-m1b.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m1/test1234"
grep -q "FAILED: You can change the site.*\[version 9.9\], made from another account or for another site" "$t/out-m1b.txt" && ok || { bad "marker: the installer is stopped on another site"; grep "change the site" "$t/out-m1b.txt"; }
echo "GROUP $pass $fail"; } > "$t/grp-MA.log" 2>&1 &
go MC; {   # group MC: runs in the background (see "go" above)
fake="$t/fake-mc.json"
# A row value that is not a version still counts as an install; a list that cannot be read is FAILED.
echo '{ "admin": false, "rights": true, "list": true, "rows": { "InstalledVersion": "v9.9 someday" } }' > "$fake"; mkround m5
grep -q "FAILED: You can change the site.*\[version not readable\]" "$t/out-m5.txt" && ok || { bad "marker: any row value is an install"; grep "change the site" "$t/out-m5.txt"; }
echo '{ "admin": false, "rights": true, "list": true, "listError": true, "rows": {} }' > "$fake"; mkround m7
grep -q "FAILED: You can change the site.*The install record on the site could not be read" "$t/out-m7.txt" && ok || { bad "marker: an unreadable record fails closed"; grep "change the site" "$t/out-m7.txt"; }
echo "GROUP $pass $fail"; } > "$t/grp-MC.log" 2>&1 &
go MD; {   # group MD: runs in the background (see "go" above)
fake="$t/fake-md.json"
# A part install (one step skipped) writes the row marked partial; that account's next run is not stopped; the row is then updated.
echo '{ "admin": false, "rights": true, "list": true, "rows": {} }' > "$fake"
mkdir -p "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-m6.ps1" "$t/m6"
psrun "$t/m-m6.ps1" "$t/out-m6.txt" $'2\n\nS\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "marked partial (added)" "$t/out-m6.txt" && grep -q '"InstalledVersion": *"[0-9.]* 20[0-9-]* partial"' "$fake" && ok || { bad "marker: a part install is recorded as partial"; tail -4 "$t/out-m6.txt"; cat "$fake"; }
mkround m6
grep -q "PASSED: You can change the site" "$t/out-m6.txt" && grep -q "now holds version [0-9.]* and the date (updated)" "$t/out-m6.txt" && ! grep -q "partial" "$fake" && ok || { bad "marker: the same account finishes its part install"; grep "change the site\|Install record" "$t/out-m6.txt"; cat "$fake"; }

# Second review, 14 Nov 26. A run that reached no step (failed download) does not make the account "installed here":
# after another account's install it is stopped, with the gate on, and the row stays.
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": {} }' > "$fake"
mkdir -p "$t/m8/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config"; echo "https://usaf.dps.mil/sites/fake" > "$t/m8/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
swap "$t/mk/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/m-m8.ps1" "$t/m8"; sed "s#file://$t/app/flow/SAMPLE-data#file://$t/app/flow/NOPE#" "$t/m-m8.ps1" > "$t/m-m8f.ps1"
psrun "$t/m-m8f.ps1" "$t/out-m8f.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m8/test1234"
grep -q "so no step ran" "$t/out-m8f.txt" && ! grep -q "InstalledVersion" "$fake" && ok || { bad "marker: a run with no step writes no row"; tail -4 "$t/out-m8f.txt"; }
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": { "InstalledVersion": "7.7 2026-01-01" } }' > "$fake"
sed -i 's#\$checkGate = \$false#$checkGate = $true#' "$t/m-m8.ps1"
psrun "$t/m-m8.ps1" "$t/out-m8.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m8/test1234"
grep -q "FAILED: You can change the site.*\[version 7.7\]" "$t/out-m8.txt" && ! grep -q "^Step 1 of" "$t/out-m8.txt" && grep -q '"7.7 2026-01-01"' "$fake" && ok || { bad "marker: a no-step run does not make the account the installer"; grep "change the site\|^Step" "$t/out-m8.txt"; cat "$fake"; }
# Step records from one site do not count on another: account m6 (whole install on site "fake") on a new, empty site
# is a first install again and runs every needed step.
echo '{ "admin": false, "rights": true, "list": true, "listError": false, "rows": {} }' > "$fake"
echo "https://usaf.dps.mil/sites/second" > "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
psrun "$t/m-m6.ps1" "$t/out-m6b.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "^First install from this account" "$t/out-m6b.txt" && grep -q "^Step 1 of [0-9]: T01 Sample check r1" "$t/out-m6b.txt" && grep -q "and the date (added)" "$t/out-m6b.txt" && ok || { bad "marker: records from another site do not count"; grep "^First\|^Step\|Install record" "$t/out-m6b.txt"; }
# A part install on a third site, then its second run: the step that never ran there (T03) runs; only then is the row whole.
echo "https://usaf.dps.mil/sites/third" > "$t/m6/test1234/OneDrive - United States Air Force/RADE/SampleApp/Config/SAMPLE-site.txt"
psrun "$t/m-m6.ps1" "$t/out-m6c.txt" $'2\n\nS\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "marked partial" "$t/out-m6c.txt" && ! grep -q "T03 Sample verify r1: PASSED" "$t/out-m6c.txt" && ok || { bad "marker: part install on a third site"; grep "T03\|Install record" "$t/out-m6c.txt"; }
psrun "$t/m-m6.ps1" "$t/out-m6d.txt" $'2\n\n\n\n' RADE_FAKE_PNP="$fake" PSModulePath="$mods" USERPROFILE="$t/m6/test1234"
grep -q "^Step [0-9] of [0-9]: T03 Sample verify r1" "$t/out-m6d.txt" && grep -q "is recorded as installed" "$t/out-m6d.txt" && ! grep -q "partial" "$fake" && ok || { bad "marker: a step that never ran on this site must run before the install is whole"; grep "^Step\|installed\|Install record" "$t/out-m6d.txt"; }
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
grep -q "installed-version record (RADE.Config.installed) could not be saved" "$t/out-m9.txt" && ! grep -q "^Install record on the site" "$t/out-m9.txt" && ! grep -q "InstalledVersion" "$fake" && ok || { bad "marker: no row when the own record failed"; grep "record" "$t/out-m9.txt"; cat "$fake"; }
echo "GROUP $pass $fail"; } > "$t/grp-MG.log" 2>&1 &
# Shared-file helpers (groups X and S): sha FILE... gives the SHA-256 of each file; valid SCHEMA FILE checks FILE against SCHEMA.
sha() { sha256sum "$@" | cut -c1-64 | tr '\n' ' '; }
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
  xrun() { psrun "$1" "$2" $'2\n\n\n\n' USERPROFILE="$t/xu/test1234"; }
  python3 engine/rade_build.py --app-root "$t/xv/app" > /dev/null 2>&1 && swap "$xb" "$t/x-new.ps1" "$t/xu"
  python3 "$t/v1/engine/rade_build.py" --app-root "$t/xv/app" > /dev/null 2>&1 && swap "$xb" "$t/x-v1.ps1" "$t/xu"
  xrun "$t/x-new.ps1" "$t/x1.txt"; h0=$(sha "$xi"); n0=$(ls "$xo/RADE/Config/installed" | wc -l)
  xrun "$t/x-v1.ps1" "$t/x2.txt"; h1=$(sha "$xi"); n1=$(ls "$xo/RADE/Config/installed" | wc -l)
  xrun "$t/x-new.ps1" "$t/x3.txt"
  ! cmp -s "$t/x-new.ps1" "$t/x-v1.ps1" && grep -q "is recorded as installed" "$t/x1.txt" && grep -q "is recorded as installed" "$t/x2.txt" && [ -f "$xo/RADE/Config/rade-installed.json" ] && [ "$h0" = "$h1" ] && [ "$n0$n1" = 11 ] && ok || { bad "cross-version: engine-v1 changed this engine's record ($n0 $n1)"; tail -3 "$t/x2.txt"; }
  grep -q "^Mode: deploy, version 1.0.0 is installed" "$t/x3.txt" && valid schemas/rade-installed.schema.json "$xi" && valid schemas/rade-checks.schema.json "$xo/RADE/Config/rade-checks.json" && ok || { bad "cross-version: this engine after engine-v1 (its record, the saved checks)"; grep "^Mode" "$t/x3.txt"; }
  # Saved checks (docs/engine.md "Results"): a slow check is reused; the fast checks ps and child run fresh (from engine-v21).
  grep -q "PASSED: Your OneDrive folder is set up. Last check: " "$t/x3.txt" && ok || bad "saved checks: the OneDrive check is not reused"
  grep -q "PASSED: PowerShell is version 5.1 or newer. Version \[" "$t/x3.txt" && ok || bad "saved checks: the ps check did not run fresh"
  grep -q "PASSED: RADE can run its scripts. Test script ran" "$t/x3.txt" && ok || bad "saved checks: the child check did not run fresh"
else bad "cross-version: the engine-v1 commit $v1 is not in this clone and could not be fetched (git fetch origin $v1)"; fi
echo "GROUP $pass $fail"; } > "$t/grp-X.log" 2>&1 &

# ---- answers: a hand step's questions after Done (docs/engine.md "Step contract"; the Administrator, 2026-11-15).
python3 scripts/check_manifest.py "$t/app/scripts/paste_bundles.json" > "$t/cm.txt" && grep -q "^\$steps += @{ Name = 'T02 Sample import r1'.*; Answers = @(@{ Key = 'run-started'; Prompt = 'Did the flow run start?'; Kind = 'yesno'; Choices = @() }, @{ Key = 'flow-count'; .*Kind = 'pick'; Choices = @('One', 'Two', 'Three or more') }, @{ Key = 'note'; .*Kind = 'text'; Choices = @() }) }$" "$b" && ! grep "^\$steps += " "$b" | grep -v "Name = 'T02 " | grep -q "Answers" && ok || { bad "answers: the schema must accept the fixture, and only its hand step gets an Answers list"; cat "$t/cm.txt"; }
# Bad lists: the schema check and the build both reject them, each with its reason.
python3 - "$t" <<'P' && ok || bad "answers: a bad list must fail the schema check and the build"
import json, subprocess, sys, pathlib, shutil
t = pathlib.Path(sys.argv[1]); good = json.loads((t / 'app/scripts/paste_bundles.json').read_text())
qs = [s for s in good['bundles'][0]['steps'] if s['name'] == 'T02 Sample import r1'][0]['answers']
def case(name, edit, check_says, build_says):
    m = json.loads(json.dumps(good)); edit(m['bundles'][0]['steps']); a = t / ('ans-' + name)
    shutil.copytree(t / 'app', a); (a / 'scripts/paste_bundles.json').write_text(json.dumps(m))
    c = subprocess.run([sys.executable, 'scripts/check_manifest.py', str(a / 'scripts/paste_bundles.json')], capture_output=True, text=True)
    b = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(a)], capture_output=True, text=True)
    assert c.returncode == 1 and check_says in c.stdout, (name, c.stdout)
    assert b.returncode != 0 and build_says in b.stderr, (name, b.stderr)
def on_script(st): st[0]['answers'] = [qs[0]]
def no_choices(st): st[2]['answers'] = [{'key': 'n', 'prompt': 'How many?', 'kind': 'pick'}]
def five(st): st[2]['answers'] = qs + [{'key': 'k%d' % i, 'prompt': 'Again?', 'kind': 'yesno'} for i in range(2)]
def twice(st): st[2]['answers'] = [qs[0], dict(qs[2], key='run-started')]
case('script', on_script, "step 'T01 Sample check r1': answers: only a guide step (kind \"guide\") can ask questions", "step 'T01 Sample check r1': answers: only a guide step (kind \"guide\") can ask questions")
case('pick', no_choices, "'choices' is a required property", "question 'n': a pick needs 2 to 4 choices")
case('five', five, 'is too long', 'answers: 1 to 4 questions, not 5')
case('twice', twice, "answers: the key 'run-started' is used twice", "question 2: the key 'run-started' is used twice")
def newline(st): st[2]['answers'] = [dict(qs[0], key='abc\n')]
def same(st): st[2]['answers'] = [dict(qs[1], choices=['One', 'One'])]
case('newline', newline, "should not be valid under {'pattern': '\\n'}", 'question 1: the key must be 1 to 24 lowercase')
case('same', same, 'has non-unique elements', "question 'flow-count': the choices of a pick must differ")
def case_sp(st): st[2]['answers'] = [dict(qs[1], choices=['One', 'one ', 'Two'])]
case('case', case_sp, "answers: the choices of 'flow-count' must differ (case and spaces ignored)", "question 'flow-count': the choices of a pick must differ (case and spaces ignored)")
P
# ---- sizes and text lengths (docs/window-design.md "Sizes", "Text lengths"; the Administrator, 2026-11-15)
# Every button is made with a named kind (its size is in $ui.Z), and no other place sets a button's size.
# (The bottom line's own minimum height, 46, is not a button size: R24. The logo block has no minimum: it is as tall as its rows, 2026-11-18.)
[ "$(cat $engine_src engine/rade_ui.ps1 | grep -o '& \$ui\.Btn [^;)]*' | sort -u | tr '\n' '|')" = "& \$ui.Btn 'action'|& \$ui.Btn 'compact'|" ] && [ "$(grep -o 'MinimumSize = [^;]*' engine/rade_ui.ps1 | wc -l)" = 2 ] && [ "$(cat $engine_src | grep -c 'MinimumSize = ')" = 3 ] && grep -q 'ui.Head.MinimumSize = ' engine/ps/window/04-record-parts.ps1 && ok || bad "sizes: a button is made without a kind, or sets its own size"
# The limits in the document are the limits of the build.
python3 - <<'P' && ok || bad "text lengths: docs/window-design.md and TEXT_LIMITS (engine/rade_build.py) differ"
import importlib.util, re, pathlib
sp = importlib.util.spec_from_file_location('rade_build', 'engine/rade_build.py'); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
doc = pathlib.Path('docs/window-design.md').read_text().split('## Text lengths')[1].split('## ')[0]
rows = dict((a.strip(), int(b)) for a, b in re.findall(r'^\| ([a-zA-Z ]+?) \| (\d+) \|', doc, re.M))
assert rows == m.TEXT_LIMITS, (rows, m.TEXT_LIMITS)
P
# A text over its limit is a WARNING line of the build, and the bundle is still built (this release warns only).
python3 - "$t" <<'P' && ok || bad "text lengths: a long summary must give a WARNING line and a built bundle"
import json, subprocess, sys, pathlib, shutil
t = pathlib.Path(sys.argv[1]); a = t / 'long'; shutil.copytree(t / 'app', a)
m = json.loads((a / 'scripts/paste_bundles.json').read_text()); m['bundles'][0]['apps'][0]['summary'] = 'x' * 151
(a / 'scripts/paste_bundles.json').write_text(json.dumps(m))
r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(a)], capture_output=True, text=True)
assert r.returncode == 0 and 'BUILT ' in r.stdout and r.stdout.count('WARNING text length: ') == 1 and 'summary has 151 characters, the limit is 150' in r.stdout, r.stdout + r.stderr
r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'app'), '--check'], capture_output=True, text=True)
assert 'WARNING' not in r.stdout, r.stdout
P

# A step title (manifest "title") of 56 characters is fine, one of 57 is a WARNING (like the step name), an empty one fails the schema; a
# guide of 10 numbered lines is fine, 11 is a WARNING of the build (a count: docs/window-design.md "Text lengths"); a line without a number
# is not counted; the title reaches the bundle and the name stays the key.
python3 - "$t" <<'P' && ok || bad "title and guide lines: build WARNINGs, schema, bundle line"
import json, subprocess, sys, pathlib, shutil
t = pathlib.Path(sys.argv[1])
def build(n, title=None, lines=None, check=False):
    a = t / ('tl%s' % n); shutil.copytree(t / 'app', a)
    p = a / 'scripts/paste_bundles.json'; m = json.loads(p.read_text())
    st = [s for s in m['bundles'][0]['steps'] if s['name'] == 'T02 Sample import r1'][0]
    if title is not None: st['title'] = title
    if lines is not None: st['guide'] = lines
    p.write_text(json.dumps(m))
    r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(a)], capture_output=True, text=True)
    c = subprocess.run([sys.executable, 'scripts/check_manifest.py', str(p)], capture_output=True, text=True)
    return r, c, a
r, c, a = build(1, 't' * 56); assert r.returncode == 0 and 'WARNING' not in r.stdout and c.returncode == 0, r.stdout + r.stderr + c.stdout
r, c, a = build(2, 't' * 57); assert r.returncode == 0 and r.stdout.count('WARNING text length: ') == 1 and 'step title has 57 characters, the limit is 56' in r.stdout, r.stdout + r.stderr
r, c, a = build(3, ''); assert c.returncode == 1 and 'title' in c.stdout, c.stdout
ten = ['%d. Do thing %d.' % (i, i) for i in range(1, 11)]
r, c, a = build(4, None, ten); assert r.returncode == 0 and 'WARNING' not in r.stdout, r.stdout + r.stderr
r, c, a = build(5, None, ten + ['11. One more.']); assert r.returncode == 0 and r.stdout.count('WARNING text length: ') == 1 and 'guide has 11 numbered lines, the limit is 10' in r.stdout, r.stdout + r.stderr
r, c, a = build(6, None, ten + ['A line with no number.', 'Another one.']); assert r.returncode == 0 and 'WARNING' not in r.stdout, r.stdout + r.stderr
r, c, a = build(7, 'Import it'); line = [l for l in (a / 'scripts/gov/paste/SAMPLE-R01-round-r1.ps1').read_text().split('\n') if l.startswith("$steps += @{ Name = 'T02 Sample import r1'")][0]
assert "Name = 'T02 Sample import r1'; Title = 'Import it'; Dir = " in line, line
r, c, a = build(8); line = [l for l in (a / 'scripts/gov/paste/SAMPLE-R01-round-r1.ps1').read_text().split('\n') if l.startswith("$steps += @{ Name = 'T03 Sample verify r1'")][0]
assert "Name = 'T03 Sample verify r1'; Title = ''; Dir = " in line, line
P

# 0. A skipped step: the run is PASSED but the version is not recorded as installed (review of deploy v1).
round 2 S; cp "$t/out.txt" "$t/out0.txt"
grep -q "^Note: some steps were off or skipped, so version 1.0.0 is not recorded as installed" "$t/out.txt" && [ "$(js)" = "rade-installed/2 1 None 1.0.0 PASSED" ] && ok || { bad "deploy 0: skipped step ($(js))"; tail -8 "$t/out.txt"; }

# Optional = "default": false only (review): T04 is optional, the other steps are needed.
[ "$(grep -c '^\$steps += .*Optional = \$false; Help = ' "$b")" = 3 ] && grep -q "^\$steps += @{ Name = 'T04 Sample optional r1'.*Default = \$false.*Optional = \$true; Help = '' }$" "$b" && ok || bad "catalog: Optional flags"
# A files-changed default that the build turns off is still a needed step: in a deploy it runs (review).
python3 - "$t" <<'P' && ok || bad "item 3: a step with a files-changed default must stay needed in a deploy"
import json, subprocess, sys, pathlib, shutil, os, re
t = pathlib.Path(sys.argv[1]); shutil.copytree(t / 'app', t / 'cond/app')
p = t / 'cond/app/scripts/paste_bundles.json'; m = json.loads(p.read_text())
ns = {'__file__': os.path.abspath('engine/rade_build.py')}; exec(open('engine/rade_build.py').read().split('\ndef here')[0], ns); ns['ROOT'] = t / 'cond/app'
paths = ['scripts/gov/SAMPLE-T01-check-r1.ps1']
m['bundles'][0]['steps'][0]['default'] = {'passed': ns['files_hash'](paths), 'paths': paths}; p.write_text(json.dumps(m))
r = subprocess.run([sys.executable, 'engine/rade_build.py', '--app-root', str(t / 'cond/app')], capture_output=True, text=True)
line = [l for l in (t / 'cond/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1').read_text().split('\n') if l.startswith("$steps += @{ Name = 'T01 Sample check r1'")][0]
assert r.returncode == 0 and 'Default = $false' in line and 'Optional = $false; Help = ' in line, line
P
go C; {   # group C: runs in the background (see "go" above)
swap "$t/cond/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1" "$t/c.ps1" "$t/cu"
mkdir -p "$t/cu/test1234/OneDrive - United States Air Force"
psrun "$t/c.ps1" "$t/outc.txt" $'2\n\n\n\n' USERPROFILE="$t/cu/test1234"
grep -q "^Step 1 of 3: T01 Sample check r1" "$t/outc.txt" && grep -q "is recorded as installed" "$t/outc.txt" && ok || { bad "item 3: files-changed default step did not run in a deploy"; grep "^Step \|installed" "$t/outc.txt"; }
echo "GROUP $pass $fail"; } > "$t/grp-C.log" 2>&1 &

# Item 5: a fetch file comes from the bundle's release tag; with a failed download a deploy runs no step.
grep -q "Url = 'https://raw.githubusercontent.com/example-org/sample-app/v1.0.0/flow/SAMPLE-data-r1.txt'; Sha = '[0-9a-f]\{64\}'" "$b" && grep -q "^  Downloaded   T02.SAMPLE-data-r1.txt" "$t/out0.txt" && ok || bad "item 5: fetch from the release tag"
sed "s#file://$t/app/flow/SAMPLE-data#file://$t/app/flow/NOPE#" "$t/b.ps1" | sed "s#usersRoot = '$t/u'#usersRoot = '$t/fu'#" > "$t/f.ps1"; mkdir -p "$t/fu/test1234/OneDrive - United States Air Force"
go F; {   # group F: runs in the background (see "go" above)
psrun "$t/f.ps1" "$t/outf.txt" $'2\n\n\n\n' USERPROFILE="$t/fu/test1234"
grep -q "could not be downloaded, so no step ran" "$t/outf.txt" && ! grep -q "^Step 1 of" "$t/outf.txt" && grep -q "^For help, ask in the Teams channel" "$t/outf.txt" && grep -q '"state":  *"STOPPED"' "$t/fu/test1234/OneDrive - United States Air Force/RADE/Config/installed/$(rec 'SampleApp/Sample app (deploy)')" && ok || { bad "item 5: a failed download must stop a deploy before its steps"; tail -8 "$t/outf.txt"; }
echo "GROUP $pass $fail"; } > "$t/grp-F.log" 2>&1 &
# A newer version in rade-release.json: in text mode it is named in a deploy only (the window shows it in a test round too).
grep -q "^A newer version, 9.0.0, of Sample app (deploy) is on the RADE page" "$t/out0.txt" && ok || bad "newer-version notice in a deploy"

# 1. First deploy: every step on, PASSED, version recorded, nothing sent.
round 2
grep -q "^Mode: deploy, version 1.0.0 (not installed yet)" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && grep -q "^Mode: deploy, version 1.0.0 (not installed yet)" "$t/out.txt" && ok || { bad "deploy 1: report has the mode line"; tail -30 "$t/out.txt"; }
# Text mode asks no question: each answer of the hand step is "not asked (text mode)", under the step's line.
[ "$(grep -A3 "^T02 Sample import r1: PASSED (confirmed by you) in " "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" | tail -3 | tr -d '\r' | tr '\n' '|')" = "  Answer run-started: not asked (text mode)|  Answer flow-count: not asked (text mode)|  Answer note: not asked (text mode)|" ] && ok || { bad "answers: text mode"; grep -A3 "^T02 Sample" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"; }
# Item 3, safe second run: T01 PASSED in run 0, so it is off now; only the two steps left run, and the version is installed.
grep -q "^Step 1 of 2: T02 Sample import r1" "$t/out.txt" && ! grep -q "contract=1" "$t/out.txt" && grep -q "^T01 Sample check r1: already done for version 1.0.0, not run again" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && ok || { bad "item 3: a step that PASSED must start off"; grep "^Step " "$t/out.txt"; }
grep -q "^Version 1.0.0 of Sample app (deploy) is recorded as installed" "$t/out.txt" && grep -q "^DONE in .*Nothing was sent\.$" "$t/out.txt" && ok || bad "deploy 1: DONE line says nothing was sent"
# The child check's probe (the Administrator, 2026-11-18): the detail says whether a script also runs with no -ExecutionPolicy setting.
grep -rq "Test script ran.*, without Bypass \[ran\]" "$t/out.txt" "$od/RADE/SampleApp/Rounds/R01" && ok || { bad "child check: the detail has no 'without Bypass [ran]'"; grep -rh "Test script" "$t/out.txt" "$od/RADE/SampleApp/Rounds/R01" | head -3; }
! grep -qi "outlook\|e-mail\|draft\|Summary copied" "$t/out.txt" && ok || { bad "deploy 1: output names Outlook, an e-mail, a draft or a copied summary"; grep -i "outlook\|e-mail\|draft\|Summary copied" "$t/out.txt"; }
[ ! -e "$cfg/rade-mail-to.txt" ] && ok || bad "deploy 1: an e-mail address file was written"
[ "$(js)" = "rade-installed/2 1 1.0.0 1.0.0 PASSED" ] && ! grep -q "test1234\|$t" "$inst" && ok || { bad "deploy 1: rade-installed.json ($(js))"; cat "$inst"; }

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
grep -q "^Mode: deploy, version 1.0.0 is installed" "$t/out.txt" && [ "$(js)" = "rade-installed/2 1 1.0.0 1.0.0 PASSED" ] && ok || bad "deploy 2: installed text ($(js))"

# Step contract (docs/engine.md): inputs as environment variables, MADE lines and "makes" in the record.
grep -q "contract=1 mode=deploy version=1.0.0 installed=1.0.0 last=PASSED site=True" "$t/out.txt" && grep -q "contract=1 mode=deploy version=1.0.0 installed= last= site=True" "$t/out0.txt" && ok || { bad "contract: step inputs"; grep "contract=" "$t/out.txt" "$t/out0.txt"; }
python3 - "$inst" <<'P' && ok || { bad "contract: steps and made lists in the record"; cat "$inst"; }
import json, sys
s = json.load(open(sys.argv[1]))['steps']
a, b = s['T01 Sample check r1'], s['T02 Sample import r1']
assert a['state'] == 'PASSED' and a['version'] == '1.0.0' and a['made'] == [{'kind': 'file', 'name': 'SAMPLE-T01-result-r1.txt'}, {'kind': 'list', 'name': 'Sample FAIL list at <SITE> and <SITE> and <SITE> for <DODID>'}], a
assert b['state'] == 'PASSED' and b['made'] == [{'kind': 'flow', 'name': 'Sample flow'}], b
P
! grep -rq "fake.example\|sites/fake\|test1234" "$inst" "$od/RADE/SampleApp/Rounds" && ! grep -v "^Working folder: " "$t/out.txt" | grep -q "fake.example\|sites/fake\|test1234" && ok || bad "contract: a site address or the ID reached the record, the report or the screen log"
grep -q "^    MADE backup of nothing (prose, not a record)" "$t/out.txt" && grep -q "^  Result: PASSED (1 passed, 0 failed" "$t/out.txt" && ok || { bad "contract: a MADE name with FAIL changed the counts, or a prose line was taken as a record"; grep "Result:" "$t/out.txt"; }

# Fallback result, and the made list in the report (item 4).
grep -q "^  Result: PASSED (fallback: read the list in the browser view at <SITE>) (1 passed, 0 failed" "$t/out.txt" && ok || { bad "fallback result line"; grep "Result:" "$t/out.txt"; }
rp="$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt"
grep -q "^Made by this app's installs" "$rp" && grep -q "^  flow: Sample flow  (T02 Sample import r1)" "$rp" && grep -q "^  file: SAMPLE-T01-result-r1.txt  (T01 Sample check r1)" "$t/out.txt" && ok || { bad "item 4: made list in the report and the log"; grep -A4 "^Made by" "$rp"; }

# 3. A test round: the draft path is unchanged and the record is not touched.
cp "$inst" "$t/inst.before"; round 1
grep -q "Outlook draft could not be created" "$t/out.txt" && ! grep -q "^Mode: deploy\|newer version\|^Made by" "$t/out.txt" && cmp -s "$inst" "$t/inst.before" && ok || { bad "test round: draft path or record changed"; tail -15 "$t/out.txt"; }
# The shared-file self-test (test rounds only; the 5.1 proof on a work computer): 4 PASS lines, the count in the report,
# no scratch folder left, and nothing new in RADE\Config\installed.
[ "$(grep -c "^  PASS shared files: " "$t/out.txt")" = 4 ] && ! grep -q "FAIL shared files" "$t/out.txt" && grep -q "^Shared-file self-test: 4 passed, 0 failed" "$od/RADE/SampleApp/Rounds/R01/SAMPLE-R01-report-r1.txt" && [ -z "$(find "$od/RADE/SampleApp/Rounds" -name 'selftest*')" ] && [ "$(ls "$cfg/installed" | wc -l)" = 1 ] && ok || { bad "shared files: self-test in a test round"; grep "shared files\|Shared-file" "$t/out.txt"; ls "$cfg/installed"; }

# 4. A newer version whose step fails: lastRun changes, installed stays 1.0.0.
sed -i 's/"version": "1.0.0"/"version": "1.1.0"/' "$t/app/scripts/paste_bundles.json"; echo "Write-Output 'FAIL sample check: forced by the test'" >> "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"
build; round 2
grep -q "^Mode: deploy, version 1.1.0 (installed now: 1.0.0)" "$t/out.txt" && grep -q "^Note: one or more items need review.*Nothing was sent\.$" "$t/out.txt" && grep -q "^For help, ask in the Teams channel RHOPE-OPS\.$" "$t/out.txt" && grep -q "^  What to do: Close other PowerShell windows, then run again\.$" "$t/out.txt" && [ "$(js)" = "rade-installed/2 1 1.0.0 1.1.0 NEEDS REVIEW" ] && ok || { bad "deploy 4: failed upgrade ($(js))"; tail -15 "$t/out.txt"; }

# 5. A damaged record is kept as .damaged and replaced by a valid file.
echo '{ not json' > "$inst"; round 2
[ -f "$inst.damaged" ] && [ "$(js)" = "rade-installed/2 2 None 1.1.0 NEEDS REVIEW" ] && ok || bad "deploy 5: damaged record ($(js))"

# 6. Item 3: the failed step is fixed; the next run does only that step and the version becomes installed.
sed -i '/forced by the test/d' "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"; build; round 2
sed -i 's/"version": "1.1.0"/"version": "1.2.0"/' "$t/app/scripts/paste_bundles.json"; echo "Write-Output 'FAIL sample check: forced by the test'" >> "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"; build; round 2
sed -i '/forced by the test/d' "$t/app/scripts/gov/SAMPLE-T01-check-r1.ps1"; build; round 2
grep -q "^Step 1 of 1: T01 Sample check r1" "$t/out.txt" && [ "$(js)" = "rade-installed/2 2 1.2.0 1.2.0 PASSED" ] && ok || { bad "item 3: resume after a failed step ($(js))"; grep "^Step \|Result" "$t/out.txt"; }

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

# ---- Guardrails (the Administrator, 14 Nov 26; docs/engine.md "Guardrails").
# 1. A computer whose full name lacks the NIPR label '.area52.' stops RADE before it writes anything (the Administrator, 15 Nov 26).
go G; {   # group G: runs in the background (see "go" above)
mkdir -p "$t/gu/test1234/OneDrive - United States Air Force"; sed "s#usersRoot = '$t/u'#usersRoot = '$t/gu'#" "$t/b.ps1" > "$t/g.ps1"
for n in 'pc01.example.invalid' 'pc01.notarea52.example.invalid' 'pc01.area52x.example.invalid' 'pc01.example.area52' 'pc01.' ''; do
  psrun "$t/g.ps1" "$t/outg.txt" $'2\n\n\n\n' RADE_TEST_FQDN="$n" USERPROFILE="$t/gu/test1234"
  [ "$(cat "$t/outg.txt")" = "This application cannot be installed in your environment." ] && [ -z "$(find "$t/gu" -type f)" ] && [ ! -d "$t/gu/test1234/OneDrive - United States Air Force/RADE" ] && ok || { bad "guard: '$n' must stop with only the message and nothing written"; head -5 "$t/outg.txt"; }
done
psrun "$t/g.ps1" "$t/outg2.txt" $'2\n\n\n\n' RADE_TEST_FQDN="PC01.AREA52.EXAMPLE.INVALID" USERPROFILE="$t/gu/test1234"
grep -q "PASSED: This computer is on NIPR (area52 domain)" "$t/outg2.txt" && ! grep -qi "example" "$t/outg2.txt" && ! grep -q "cannot be installed" "$t/outg2.txt" && ok || { bad "guard: an area52 name in capitals must pass and never be shown"; head -5 "$t/outg2.txt"; }
grep -q "PASSED: This computer is on NIPR (area52 domain)" "$t/out0.txt" && ok || bad "guard: the check line is in a normal run"
echo "GROUP $pass $fail"; } > "$t/grp-G.log" 2>&1 &
# ---- Bundle hash (docs/specs/bundle-hash.md; the Administrator, 2026-11-18). The build: the first line holds the SHA-256
# of the text after it, the stored file beside the bundle says the same, and --check sees a missing or changed stored file.
hb="$t/app/scripts/gov/paste/SAMPLE-R01-round-r1.ps1"
python3 - "$hb" <<'P' && ok || bad "bundle hash: the first line, the stored file and the text do not agree"
import hashlib, json, re, sys
t = open(sys.argv[1], newline='').read(); first, rest = t.split('\n', 1); j = json.load(open(sys.argv[1] + '.sha256.json'))
sha = hashlib.sha256(rest.encode()).hexdigest()
assert first == '# @@BUNDLE-HASH %s @@' % sha, first
assert j['sha256'] == sha and j['short'] == sha[:12] + '...' + sha[-4:] and j['file'] == 'SAMPLE-R01-round-r1.ps1' and j['engineRelease'] > 0, j
assert re.search(r"(?m)^\$buildId = '%s'$" % j['buildId'], t), j
P
python3 engine/rade_build.py --app-root "$t/app" --check > /dev/null && cp "$hb.sha256.json" "$t/hj" && echo x >> "$hb.sha256.json" && ! python3 engine/rade_build.py --app-root "$t/app" --check > /dev/null && rm "$hb.sha256.json" && ! python3 engine/rade_build.py --app-root "$t/app" --check > /dev/null && cp "$t/hj" "$hb.sha256.json" && ok || bad "bundle hash: --check must fail on a changed or missing stored file"
# The bundle checks itself. The test copy is a changed text (swap), so it must say so; with the first line made right again
# it must say "checked", also when every line ends in CR LF (as a paste in ISE can make it) and with a blank line above.
go H; {   # group H: runs in the background (see "go" above)
mkdir -p "$t/hu/test1234/OneDrive - United States Air Force"; sed "s#usersRoot = '$t/u'#usersRoot = '$t/hu'#" "$t/b.ps1" > "$t/h1.ps1"
python3 - "$t/h1.ps1" "$t/h2.ps1" "$t/h3.ps1" <<'P'
import hashlib, sys
first, rest = open(sys.argv[1], newline='').read().split('\n', 1)
good = '# @@BUNDLE-HASH %s @@\n' % hashlib.sha256(rest.encode()).hexdigest() + rest
open(sys.argv[2], 'w', newline='').write(good)
open(sys.argv[3], 'w', newline='').write('\r\n' + good.replace('\n', '\r\n'))
P
for n in 1 2 3; do psrun "$t/h$n.ps1" "$t/outh$n.txt" $'2\n\n\n\n' USERPROFILE="$t/hu/test1234"; done
sed -n 2p "$t/outh1.txt" | grep -q "^Script check: [0-9a-f]\{12\}\.\.\.[0-9a-f]\{4\} DOES NOT MATCH the line in the script ([0-9a-f]\{12\}\.\.\.[0-9a-f]\{4\})$" && ok || { bad "bundle hash: a changed bundle must say DOES NOT MATCH on its second line"; head -3 "$t/outh1.txt"; }
want="Script check: $(python3 -c "import sys; h=open(sys.argv[1]).readline().split()[2]; print(h[:12]+'...'+h[-4:])" "$t/h2.ps1") (checked)"
[ "$(sed -n 2p "$t/outh2.txt")" = "$want" ] && [ "$(sed -n 2p "$t/outh3.txt")" = "$want" ] && ok || { bad "bundle hash: a whole bundle must say '$want' (LF and CR LF)"; sed -n 2p "$t/outh2.txt" "$t/outh3.txt"; }
grep -rqF "$want" "$t/hu/test1234/OneDrive - United States Air Force/RADE" && ok || bad "bundle hash: the line is in the round's log or report"
echo "GROUP $pass $fail"; } > "$t/grp-H.log" 2>&1 &
# 2. Only a site on the DAF SharePoint host is accepted.
grep "^\$sitePrefix = \|^function Test-SiteUrl" "$t/b.ps1" > "$t/site.ps1"
cat >> "$t/site.ps1" <<'P'
$bad = @('https://example.com/sites/a', 'http://usaf.dps.mil/sites/a', 'https://usaf.dps.mil/teams/a', 'https://usaf.dps.mil/sites/a/b', 'https://usaf.dps.mil.example.com/sites/a', 'https://usaf.dps.mil/sites/a\', 'https://usaf.dps.mil/sites/', '') | Where-Object { Test-SiteUrl $_ }
$good = @('https://usaf.dps.mil/sites/a', 'https://USAF.dps.mil/sites/a-b_1/') | Where-Object { -not (Test-SiteUrl $_) }
if (@($bad).Count -or @($good).Count) { 'WRONG ' + (@($bad) + @($good) -join ' '); exit 1 }
'SITEOK'
P
[ "$(grep -c "^\$sitePrefix = \|^function Test-SiteUrl" "$t/site.ps1")" = 2 ] && pwsh -NoProfile -File "$t/site.ps1" > "$t/outsite.txt" 2>&1 && [ "$(cat "$t/outsite.txt")" = "SITEOK" ] && ok || { bad "site address rule"; cat "$t/outsite.txt"; }
# 3 and 4 (site rights and the install record on the site): groups MA to MG, started near the top (after the window).

# ---- Shared files (docs/engine.md "Shared files"; the Administrator, 2026-11-15): many apps, each with its own engine
# version, use RADE\Config. Fixtures are files the engines wrote; the hand-made ones only stand for another app's file.
go S; {   # group S: runs in the background (see "go" above)
# The files the engine wrote in the runs above follow the two schemas.
valid schemas/rade-installed.schema.json "$inst" && valid schemas/rade-checks.schema.json "$cfg/rade-checks.json" && ok || bad "shared files: the engine's files do not follow schemas/rade-installed.schema.json and rade-checks.schema.json"
# S1 and S5. A deploy of one app changes no other file in RADE\Config\installed: another app's record (with fields this
# engine does not know) and a OneDrive conflict copy of this app's own record stay byte for byte.
other="$cfg/installed/0123456789ab.json"; conflict="${inst%.json}-PC2.json"
echo '{ "schema": "rade-installed/7", "key": "OtherApp/Other", "later": { "a": { "b": { "c": { "d": { "e": { "f": { "g": { "h": { "i": { "j": [1] } } } } } } } } } }, "big": 12345678901234567890 }' > "$other"
sed 's/"version": *"[0-9.]*"/"version": "8.8.8"/' "$inst" > "$conflict"
h0=$(sha "$other" "$conflict"); round 2
[ "$(sha "$other" "$conflict")" = "$h0" ] && grep -q "^Mode: deploy, version 1.2.0 is installed" "$t/out.txt" && ! grep -q "8\.8\.8" "$t/out.txt" && ok || { bad "shared files: a deploy changed another app's record or read a conflict copy"; grep "^Mode" "$t/out.txt"; }
rm -f "$other" "$conflict"
# S4. A record that cannot be replaced (read-only) stays whole and the run says so; no temporary file is left.
chmod a-w "$inst"; h0=$(sha "$inst"); round 2; chmod u+w "$inst"
[ "$(sha "$inst")" = "$h0" ] && grep -q "installed-version record (RADE.Config.installed) could not be saved: .*read-only" "$t/out.txt" && [ -z "$(find "$cfg" -name '*.tmp*')" ] && ok || { bad "shared files: a read-only record must stay whole"; grep "record" "$t/out.txt"; find "$cfg" -name '*.tmp*'; }
# A record cut in the middle of a write by something else: kept as .damaged, replaced by a whole file that follows the schema.
rm -f "$inst.damaged"; head -c 150 "$inst" > "$t/cut.json"; cp "$t/cut.json" "$inst"; round 2
cmp -s "$inst.damaged" "$t/cut.json" && valid schemas/rade-installed.schema.json "$inst" && ok || { bad "shared files: a cut record"; ls "$cfg/installed"; }
# S2. A record from a newer RADE (a higher schema number): not written, and no step runs.
cp "$inst" "$t/inst.good"; echo '{ "schema": "rade-installed/3", "key": "SampleApp/Sample app (deploy)", "later": true }' > "$inst"; h0=$(sha "$inst"); round 2
[ "$(sha "$inst")" = "$h0" ] && grep -q "^Mode: deploy, version 1.2.0 (a newer RADE installed this application: get the newest script from the RADE page)" "$t/out.txt" && grep -q "^STOPPED: a newer RADE installed this application.*No step ran" "$t/out.txt" && ! grep -q "^Step 1 of\|^  Wrote\|^  Written\|^  Downloaded" "$t/out.txt" && [ -z "$(find "$cfg" -name '*.tmp*')" ] && ok || { bad "shared files: a record of a newer RADE must stop the deploy and stay as it is"; grep "^Mode\|^STOPPED\|^Step\|record" "$t/out.txt"; }
# S1. Two record keys that give one file name: the file holds a whole record of another app. Not written, no step runs.
sed 's#"key": *"SampleApp/Sample app (deploy)"#"key": "SampleApp/Another app"#' "$t/inst.good" > "$inst"; h0=$(sha "$inst"); round 2
grep -q '"key": "SampleApp/Another app"' "$inst" && [ "$(sha "$inst")" = "$h0" ] && grep -q "^STOPPED: the install record file of this application holds the record of another application.*No step ran" "$t/out.txt" && ! grep -q "^Step 1 of" "$t/out.txt" && [ ! -e "$inst.damaged-"* ] && ok || { bad "shared files: a record with another app's key must stay as it is"; grep "^Mode\|^STOPPED\|^Step\|record" "$t/out.txt"; ls "$cfg/installed"; }
# A second damaged record does not replace the first .damaged copy.
echo '{ cut' > "$inst"; round 2
cmp -s "$inst.damaged" "$t/cut.json" && [ "$(ls "$cfg/installed" | grep -c '\.damaged-[0-9]\{8\}-[0-9]\{6\}$')" = 1 ] && ok || { bad "shared files: a second damaged record must keep the first copy"; ls "$cfg/installed"; }
cp "$t/inst.good" "$inst"
echo "GROUP $pass $fail"; } > "$t/grp-S.log" 2>&1 &

# Moved from rhope-ops/90-161.Z tests (2026-11-15): engine behavior is tested here, an app tests its own bundle.
# Step default: a bool, or {passed, paths}: on only when those files changed since the round that last passed them.
sd=$(python3 - <<'P'
import os
ns = {'__file__': os.path.abspath('engine/rade_build.py')}; exec(open('engine/rade_build.py').read().split('\ndef here')[0], ns)
import pathlib; ns['ROOT'] = pathlib.Path('.').resolve()
p = ['schemas/examples/sample-manifest.json']; h = ns['files_hash'](p)
print(ns['step_default']({'default': {'passed': h, 'paths': p}}), ns['step_default']({'default': {'passed': 'x', 'paths': p}}),
      ns['step_default']({}), ns['step_default']({'default': False}))
P
)
[ "$sd" = "False True True False" ] && ok || bad "step default by hash: $sd"
# Two bars: progress math, the PROGRESS line rule and the check gate, from the sample bundle's own functions.
pg=$(pwsh -NoProfile -File tests/progress_test.ps1 -Bundle "$b" 2>&1)
[ "$(echo $pg)" = "0.10 0.28 101 | -1 0.375 0.50 | True True False gate False True True True" ] && ok || bad "progress math and gate: got '$pg'"
# Fonts: New-Object with a string for an enum argument can match two overloads ("Multiple ambiguous overloads") and
# drop the window to text mode. No Font() call in the engine or the sample bundle may pass a string enum.
fa=$(grep -ohE "(New-Object System\.Drawing\.Font|\[System\.Drawing\.Font\]::new)\([^)]*,[^)]*, *[\"'][A-Za-z]+[\"'] *\)" $engine_src "$b" | wc -l)
amb=$(pwsh -NoProfile -c 'Add-Type -AssemblyName System.Drawing.Common; try { $null = New-Object System.Drawing.Font("Segoe UI", 10, "Bold"); "bound" } catch { if ($_.Exception.Message -match "ambiguous") { "ambiguous" } else { "bound" } }' 2>&1 | tail -1)
[ "$fa" -eq 0 ] && [ "$amb" = "ambiguous" ] && ok || bad "fonts: string enum in Font() found=$fa (pwsh: $amb)"
# Outlook draft: made when Outlook answers, with a fallback text when it does not (the run above shows the fallback).
grep -q '\$script:draftMade = (-not \$why)' $engine_src && grep -q "Outlook draft could not be created" $engine_src && ok || bad "Outlook draft fallback"

# The tagline (the Administrator, 18 Nov 26): "Test, deploy, enjoy"; no "DoD".
! grep -q "for your DoD organization" $engine_src && grep -q "'Test, deploy, enjoy'" $engine_src && ok || bad "tagline"
psclose; gather   # wait for the groups and add their results
echo "ENGINE pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
