#!/usr/bin/env bash
# Network rules of the RADE checks (engine/ps/07-checks.ps1; the Administrator, 2026-11-17): a Power Automate address
# from Config is used only on the host of the step's own fixed address (the check, the step run and the hand step), and
# the reach test sends no Windows sign-in to the address it tests (only the proxy gets it).
# Network: none. Writes: temporary files, deleted on exit. Credentials: none.
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
# Get-FlowPortal, run: a saved address on the fixed host is used; one on another host is not, and is reported.
{ cat "$t/host.ps1" | sed '/^\$f = /,$d'; awk '/^function Get-FlowPortal/{on=1} on{print} on&&/^}/{exit}' "$src"; cat <<'P'
function Get-ConfigFile([string]$Base, [string]$Name) { return (Join-Path $Base $Name) }
$script:appSteps = @('a'); $steps = @{ a = @{ Url = 'https://make.powerautomate.com/'; UrlConfig = 'flow.txt' } }
$d = Join-Path ([IO.Path]::GetTempPath()) ('nr' + [guid]::NewGuid().ToString('N')); $null = New-Item -ItemType Directory -Path $d
Set-Content -LiteralPath (Join-Path $d 'flow.txt') -Value 'https://make.powerautomate.com/environments/x'
$a = Get-FlowPortal $d
Set-Content -LiteralPath (Join-Path $d 'flow.txt') -Value 'https://evil.example/'
$b = Get-FlowPortal $d
Remove-Item -LiteralPath $d -Recurse -Force
if ($a.Url -eq 'https://make.powerautomate.com/environments/x' -and -not $a.Refused -and $b.Url -eq 'https://make.powerautomate.com/' -and $b.Refused) { 'PORTALOK' } else { 'WRONG' }
P
} > "$t/portal.ps1"
[ "$(pwsh -NoProfile -File "$t/portal.ps1" 2>&1)" = "PORTALOK" ] || { echo "FAIL Get-FlowPortal uses or hides a saved address on another host"; fail=1; }
# Test-WebReach sets no credentials for the tested address: only the proxy gets any.
reach=$(awk '/^function Test-WebReach/{on=1} on{print} on&&/^}/{exit}' "$src")
printf '%s' "$reach" | grep -q 'UseDefaultCredentials = \$false' && ! printf '%s' "$reach" | grep -v 'Proxy.Credentials' | grep -qE 'UseDefaultCredentials = \$true|\.Credentials *=' \
  || { echo "FAIL Test-WebReach sends the Windows sign-in to the tested address"; fail=1; }
# The hand step and the step run check the host too.
grep -q 'Test-SameHost \$u \$fixed' engine/ps/window/08-hand-step.ps1 && grep -q 'Test-SameHost \$v \$Step.Url' engine/ps/04-steps.ps1 \
  || { echo "FAIL the hand step or the step run uses a saved address on another host"; fail=1; }
[ "$fail" = 0 ] && echo "NETRULES pass" || { echo "NETRULES fail"; exit 1; }
