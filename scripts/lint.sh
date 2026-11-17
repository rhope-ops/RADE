#!/usr/bin/env bash
# Lint the RADE engine as it ships (the Administrator, 2026-11-17; docs/code-standard.md C10). It builds the sample app
# (schemas/examples/sample-manifest.json + tests/fixture-app) into a temporary folder and runs PSScriptAnalyzer on the
# bundle with the settings rhope-ops/90-161.Z uses on its own bundles (plus parse errors): Error and Warning, Windows PowerShell 5.1 syntax,
# Write-Host allowed. Linting the joined bundle (not each engine/ps part alone) avoids false "unused variable" findings
# for a value one part sets and another reads.
# Usage: scripts/lint.sh. Pass = last line "LINT findings=0"; exit 1 on any finding.
# Needs: pwsh 7 and PSScriptAnalyzer: in the module path (the GitHub runner has it), or at $PSSA (default
# /opt/psmods/PSScriptAnalyzer/PSScriptAnalyzer.psd1; setup: rhope-ops/90-161.Z docs/dev-setup.md).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PSSA="${PSSA:-/opt/psmods/PSScriptAnalyzer/PSScriptAnalyzer.psd1}"; export PSSA
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
cp -r tests/fixture-app/. "$t/"; mkdir -p "$t/scripts"; cp schemas/examples/sample-manifest.json "$t/scripts/paste_bundles.json"
python3 engine/rade_build.py --app-root "$t" > /dev/null
export LINT_DIR="$t/scripts/gov/paste"
pwsh -NoProfile -Command '
$ErrorActionPreference = "Stop"
if (Test-Path -LiteralPath $env:PSSA) { Import-Module $env:PSSA } else { Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue }
if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) { "LINT FAIL: PSScriptAnalyzer is not installed (set PSSA or install the module)"; exit 1 }
$settings = @{ Severity = @("Error", "Warning", "ParseError"); Rules = @{ PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @("5.1") } }; ExcludeRules = @("PSAvoidUsingWriteHost") }
$files = @(Get-ChildItem -Path $env:LINT_DIR -Filter *.ps1)
$all = foreach ($f in $files) { Invoke-ScriptAnalyzer -Path $f.FullName -Settings $settings }
$all | Format-Table RuleName, Severity, Line, Message -AutoSize -Wrap | Out-String -Width 220
"LINT bundles=" + $files.Count
"LINT findings=" + @($all).Count
if (@($all).Count -gt 0 -or $files.Count -eq 0) { exit 1 }
'
