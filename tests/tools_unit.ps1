# RADE test: the Maintenance tools Diagnose and Back up (engine/ps/13-maintenance.ps1), on the engine parts themselves
# (no bundle, no window), with the fake PnP.PowerShell of tests/fake-pnp (no SharePoint, no network).
# Run by tests/resume_test.sh: pwsh -NoProfile -File tests/tools_unit.ps1 <scratch folder>.
# Prints one PASS or FAIL line for each case, then "TOOLS-UNIT pass=N fail=M".
# Network: none (the fake PnP refuses every address but the fake site's).
# Writes: only inside the scratch folder it is given.
# Credentials: none.
# Runs on PowerShell 7 (the cloud tests).
param([Parameter(Mandatory = $true)][string]$Dir)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($p in '01-base', '02-config', '03-files', '04-steps', '05-installed', '07-checks', '08-saved-checks', '13-maintenance') { . (Join-Path $root ('engine/ps/' + $p + '.ps1')) }
# What a bundle sets before the engine: fake data only.
$round = 'R01'; $buildId = 'abcd1234'; $engineRelease = 30; $appFolder = 'SampleApp'; $sitePrefix = 'https://usaf.dps.mil/sites/'
$script:appChecks = @(); $script:runLog = New-Object System.Collections.Generic.List[string]
$script:pass = 0; $script:fail = 0
# Records one case. Takes the case name and whether it held.
function Assert-Case([string]$Name, [bool]$Ok) { if ($Ok) { $script:pass++; Write-Host ('PASS ' + $Name) } else { $script:fail++; Write-Host ('FAIL ' + $Name) } }
# Writes the fake site's state. Takes the state table.
function Set-Fake($S) { $S | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $env:RADE_FAKE_PNP }

$env:RADE_FAKE_PNP = Join-Path $Dir 'fake.json'; $env:PSModulePath = (Join-Path $root 'tests/fake-pnp') + [System.IO.Path]::PathSeparator + $env:PSModulePath
$base = Join-Path $Dir 'RADE\SampleApp'; $null = New-Item -ItemType Directory -Path $base -Force
# The app folder of the test (the bundle's Get-BasePath finds it in OneDrive). Takes nothing.
function Get-BasePath { return $base }
# The RADE folder of the test: the scratch folder stands for OneDrive\RADE. Takes nothing.
function Get-RadePath { return (Join-Path $Dir 'RADE') }
# Field values as SharePoint gives them (fake data): person, link, managed metadata, several lookups, a date.
$one = @{ Title = 'One'; Owner = @{ LookupId = 7; LookupValue = 'Sample Person' }; Link = @{ Url = 'https://example.invalid/a'; Description = 'Page' }
  Area = @{ Label = 'North'; TermGuid = '00000000-0000-0000-0000-000000000001' }; Tags = @(@{ LookupId = 1; LookupValue = 'A' }, @{ LookupId = 2; LookupValue = 'B' })
  Due = '2026-11-20T12:00:00Z' }
$tasks = @($one, @{ Title = 'Two'; Owner = $null })
Set-Fake @{ admin = $true; rights = $true; list = $true; rows = @{}; items = @{ 'Sample Tasks' = $tasks; 'Sample Settings' = @()
  '2' = @(@{ Title = 'from-list-2' }); 'X' = @(@{ Title = 'from-list-X' }) } }

# Back up with no lists named: says so, writes nothing.
$script:app = @{ Name = 'Sample app'; Version = '1.0.0'; Backup = @() }
$r = Invoke-Backup $base $null
$none = -not (Test-Path -LiteralPath (Join-Path $base 'Backups'))
Assert-Case 'backup: no lists named says so and writes nothing' ($r.State -eq 'none' -and $none -and ($r.Lines[0] -like '*names no lists to back up*'))
# Back up with no site address: stops before the sign-in.
$script:app.Backup = @('Sample Tasks')
$r = Invoke-Backup $base $null
Assert-Case 'backup: no site address stops before the sign-in' ($r.State -eq 'no-site' -and -not (Test-Path -LiteralPath (Join-Path $base 'Backups')))
Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake'
# Back up of two lists and one list that is not there: each saved list has a JSON and a CSV file with its rows; the missing one is named.
$script:app.Backup = @('Sample Tasks', 'Sample Settings', 'Sample Missing')
$r = Invoke-Backup $base $null
$j = Join-Path $r.Path 'Sample Tasks.json'; $c = Join-Path $r.Path 'Sample Tasks.csv'
Assert-Case 'backup: a new folder in Backups' ($r.Path -and (Split-Path -Parent $r.Path) -eq (Join-Path $base 'Backups') -and (Test-Path -LiteralPath $r.Path -PathType Container))
$rows = @(); if (Test-Path -LiteralPath $j) { $rows = @(Get-Content -LiteralPath $j -Raw | ConvertFrom-Json) }
Assert-Case 'backup: the JSON file holds every row' ($rows.Count -eq 2 -and $rows[0].Title -eq 'One')
Assert-Case 'backup: a lookup or person value is kept as id;#text' ([string]$rows[0].Owner -eq '7;#Sample Person')
Assert-Case 'backup: a link is kept as url;#text' ([string]$rows[0].Link -eq 'https://example.invalid/a;#Page')
Assert-Case 'backup: managed metadata is kept as label|guid' ([string]$rows[0].Area -eq 'North|00000000-0000-0000-0000-000000000001')
Assert-Case 'backup: several lookups are kept, joined with ;#' ([string]$rows[0].Tags -eq '1;#A;#2;#B')
# The raw text: ConvertFrom-Json would read it as a date. 7 digits and Z: the date was converted, not copied.
Assert-Case 'backup: a date is kept in ISO form (UTC)' ((Get-Content -LiteralPath $j -Raw) -match '"Due":\s*"2026-11-20T12:00:00\.0000000Z"')
$csvText = Get-Content -LiteralPath $c -Raw
Assert-Case 'backup: no value is saved as a type name' ($csvText -notmatch 'Microsoft\.|System\.' -and (Get-Content -LiteralPath $j -Raw) -notmatch 'Microsoft\.|System\.')
Assert-Case 'backup: the CSV copy holds every row' ((Test-Path -LiteralPath $c) -and @(Import-Csv -LiteralPath $c).Count -eq 2)
$sj = Join-Path $r.Path 'Sample Settings.json'
Assert-Case 'backup: an empty list gives an empty JSON array' ((Test-Path -LiteralPath $sj) -and @(Get-Content -LiteralPath $sj -Raw | ConvertFrom-Json).Count -eq 0)
$all = $r.Lines -join ' '
$named = $all -like '*FINDING: "Sample Missing" was not saved*'
Assert-Case 'backup: a list that cannot be read is reported, not skipped' ($r.State -eq 'failed' -and $named -and $all -like '*PASS: "Sample Tasks": 2 rows saved*')
Assert-Case 'backup: the lines say nothing on the site changed' (($r.Lines -join ' ') -like '*Nothing on the site changed*')
Assert-Case 'backup: no file is left under its number' (@(Get-ChildItem -LiteralPath $r.Path -Filter '~*').Count -eq 0)
# A second backup makes a new folder (the time stamp has seconds).
Start-Sleep -Seconds 1; $script:app.Backup = @('Sample Tasks'); $r2 = Invoke-Backup $base $null
Assert-Case 'backup: a second backup makes a new folder' ($r2.State -eq 'done' -and $r2.Path -ne $r.Path -and @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory).Count -eq 2)
# The fake site holds the same rows after the backups: nothing on the site changed.
$after = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
Assert-Case 'backup: the site rows are the same after it' (@($after.items.'Sample Tasks').Count -eq 2 -and @($after.rows.PSObject.Properties).Count -eq 0)
# A run that cannot sign in (no SharePoint tool here) saves nothing and leaves no folder behind.
$keep = $env:PSModulePath; $env:PSModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ -notlike '*fake-pnp*' }) -join [System.IO.Path]::PathSeparator
$r3 = Invoke-Backup $base $null; $env:PSModulePath = $keep
$n3 = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory).Count
Assert-Case 'backup: a run that saved nothing leaves no folder' ($r3.State -eq 'failed' -and -not $r3.Path -and $n3 -eq 2 -and ($r3.Lines[0] -like 'Back up saved nothing:*'))
# A folder of the same time stamp is there already: a new one is made (-2), so the old one is never the folder a failed
# run removes (Clear-BackupDir gets only the folder Get-NewBackupDir made).
$old = Join-Path (Join-Path $base 'Backups') '20991231-235959'; $null = New-Item -ItemType Directory -Path $old; Set-Content -LiteralPath (Join-Path $old 'keep.json') -Value '[]'
$nd = Get-NewBackupDir $base '20991231-235959'
Assert-Case 'backup: a folder of the same time is never reused' ($nd -eq ($old + '-2') -and (Test-Path -LiteralPath (Join-Path $old 'keep.json')))
Remove-Item -LiteralPath $nd, $old -Recurse -Force
# A list titled with digits only and another list: each file holds its own list (no name clash with the numbered files).
Start-Sleep -Seconds 1; $script:app.Backup = @('2', 'X'); $r4 = Invoke-Backup $base $null
$x2 = @(); $xx = @()
if ($r4.Path) { $x2 = @(Get-Content -LiteralPath (Join-Path $r4.Path '2.json') -Raw | ConvertFrom-Json); $xx = @(Get-Content -LiteralPath (Join-Path $r4.Path 'X.json') -Raw | ConvertFrom-Json) }
Assert-Case 'backup: a list titled with digits keeps its own rows' ($r4.State -eq 'done' -and $x2[0].Title -eq 'from-list-2' -and $xx[0].Title -eq 'from-list-X')

# Diagnose with no install record: one finding that names the fix, and the report file in Diagnose (not Rounds: the e-mail).
$script:app = @{ Name = 'Sample app'; Version = '1.0.0'; Backup = @(); Start = '' }
$d = Invoke-Diagnose $base $null
Assert-Case 'diagnose: no install record is a finding with its fix' ($d.Findings -ge 1 -and ($d.Lines -join ' ') -like '*FINDING: This computer has no install record*What to do: Select "Repair"*')
Assert-Case 'diagnose: the report is in Diagnose' ($d.Path -and (Split-Path -Parent $d.Path) -eq (Join-Path $base 'Diagnose') -and (Test-Path -LiteralPath $d.Path))
Assert-Case 'diagnose: nothing goes to the round results folder' (-not (Test-Path -LiteralPath (Join-Path $base 'Rounds')))
Assert-Case 'diagnose: the report says it changed nothing' (($d.Lines[0]) -like '*Read-only: nothing was changed*')
# Diagnose with an install record of an older version and a missing start script.
Save-Installed 'PASSED' $true @{ 'T01 One' = @{ state = 'PASSED'; made = @() } } | Out-Null
$script:app.Version = '1.2.0'; $script:app.Start = 'App/Start-App.ps1'
$d = Invoke-Diagnose $base $null; $all = $d.Lines -join ' '
Assert-Case 'diagnose: an older install names the update' ($all -like '*FINDING: The installed version is 1.0.0; this paste has 1.2.0*Update to 1.2.0*')
Assert-Case 'diagnose: a missing start script names the file and the fix' ($all -like '*FINDING: The start script App/Start-App.ps1 is missing from the app folder*Repair*')
# The same version and the start script in place: no finding for either.
$script:app.Version = '1.0.0'; $sp = Join-Path $base 'App'; $null = New-Item -ItemType Directory -Path $sp -Force; Set-Content -LiteralPath (Join-Path $sp 'Start-App.ps1') -Value '# fake'
$d = Invoke-Diagnose $base $null; $all = $d.Lines -join ' '
$ok = $all -like '*PASS: The installed version, 1.0.0, is the version in this paste*' -and $all -notlike '*FINDING: The start*'
Assert-Case 'diagnose: a good install says PASS' ($ok -and $all -like '*PASS: The start script App/Start-App.ps1 is in the app folder*')
# D0: the app's checks run again; a check that runs on its own gives one line with its state.
$script:appChecks = @('ps'); $d = Invoke-Diagnose $base $null; $all = $d.Lines -join ' '
Assert-Case 'diagnose: D0 runs the app checks again' ($all -match '(PASS|FINDING): [^:]+: (PASSED|WARNING|FAILED|NOT RUN)')
Write-Host ('TOOLS-UNIT pass=' + $script:pass + ' fail=' + $script:fail)
