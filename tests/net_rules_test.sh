#!/usr/bin/env bash
# Network rules of the RADE checks (engine/ps/07-checks.ps1; the Administrator, 2026-11-17): a Power Automate address
# from Config is used only on the host of the app's own fixed address, and the reach test sends no Windows sign-in to
# the address it tests (only the proxy gets it).
# Network: none. Writes: one temporary .ps1 file, deleted on exit. Credentials: none.
# Run: tests/net_rules_test.sh (scripts/check.local.sh runs it in both lanes). Needs pwsh 7. Pass = "NETRULES pass".
set -euo pipefail
cd "$(dirname "$0")/.."
src=engine/ps/07-checks.ps1
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
awk '/^function Test-SameHost/{on=1} on{print} on&&/^}/{exit}' "$src" > "$t/host.ps1"
cat >> "$t/host.ps1" <<'P'
$f = 'https://make.powerautomate.com/environments'
$bad = @('https://example.com/x', 'http://make.powerautomate.com/x', 'https://make.powerautomate.com.example.com/x', 'not a url', '') | Where-Object { Test-SameHost $_ $f }
$good = @('https://make.powerautomate.com/other', 'https://MAKE.powerautomate.com/') | Where-Object { -not (Test-SameHost $_ $f) }
if (@($bad).Count -or @($good).Count) { 'WRONG ' + (@($bad) + @($good) -join ' '); exit 1 }
'HOSTOK'
P
fail=0
[ -s "$t/host.ps1" ] && [ "$(pwsh -NoProfile -File "$t/host.ps1" 2>&1)" = "HOSTOK" ] || { echo "FAIL host rule (Test-SameHost)"; fail=1; }
grep -q 'Test-SameHost \$v \$s.Url' "$src" || { echo "FAIL Get-FlowPortal does not check the Config address host"; fail=1; }
reach=$(awk '/^function Test-WebReach/{on=1} on{print} on&&/^}/{exit}' "$src")
printf '%s' "$reach" | grep -q 'UseDefaultCredentials = \$false' && ! printf '%s' "$reach" | grep -q 'UseDefaultCredentials = \$true' \
  || { echo "FAIL Test-WebReach sends the Windows sign-in to the tested address"; fail=1; }
[ "$fail" = 0 ] && echo "NETRULES pass" || { echo "NETRULES fail"; exit 1; }
