# RADE test: the Maintenance tools Diagnose, Back up and Restore (engine/ps/13-maintenance.ps1), on the engine parts themselves
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

# ---- Restore (engine-v31). Two lists: Sample Pubs and Sample Endorse (its lookup "Pub" reads Sample Pubs), and a list
# whose title has parentheses (R39). Fake data only.
$g1 = '11111111-1111-1111-1111-111111111111'; $g2 = '22222222-2222-2222-2222-222222222222'; $g3 = '33333333-3333-3333-3333-333333333333'
$tf = @{ InternalName = 'Title'; TypeAsString = 'Text' }; $ro = @{ InternalName = 'Modified'; TypeAsString = 'DateTime'; ReadOnlyField = $true }
$pubF = @($tf, $ro, @{ InternalName = 'Owner'; TypeAsString = 'User' }, @{ InternalName = 'Link'; TypeAsString = 'URL' }, @{ InternalName = 'Due'; TypeAsString = 'DateTime' })
$endF = @($tf, @{ InternalName = 'Pub'; TypeAsString = 'Lookup'; SchemaXml = ('<Field Type="Lookup" List="{' + $g1 + '}" ShowField="Title" />') })
$pubs = @(@{ ID = 1; Title = 'P1' }, @{ ID = 2; Title = 'P2'; Owner = @{ LookupId = 7; LookupValue = 'Sample Person' } },
  @{ ID = 3; Title = 'P3'; Link = @{ Url = 'https://example.invalid/p3'; Description = 'Page' }; Due = '2026-11-20T12:00:00Z' })
$ends = @(@{ ID = 1; Title = 'E1'; Pub = @{ LookupId = 2; LookupValue = 'P2' } }, @{ ID = 2; Title = 'E2'; Pub = @{ LookupId = 3; LookupValue = 'P3' } })
$recs = @(@{ ID = 1; Title = 'R1' })
$meta = @{ 'Sample Pubs' = @{ id = $g1; url = 'sites/fake/Lists/SamplePubs'; next = 4; fields = $pubF }
  'Sample Endorse' = @{ id = $g2; url = 'sites/fake/Lists/SampleEndorse'; next = 3; fields = $endF }
  'Sample Recs (Form 1)' = @{ id = $g3; url = 'sites/fake/Lists/SampleRecs'; next = 2; fields = @($tf) } }
Set-Fake @{ admin = $true; rights = $true; list = $true; rows = @{ RestorePause = 'Off' }; log = @(); bin = @(); meta = $meta
  items = @{ 'Sample Pubs' = $pubs; 'Sample Endorse' = $ends; 'Sample Recs (Form 1)' = $recs } }
Remove-Item -LiteralPath (Join-Path $base 'Backups') -Recurse -Force
$pause = @{ List = 'Sample Settings'; Title = 'RestorePause'; Field = 'SettingValue'; On = 'On' }
$script:app = @{ Name = 'Sample app'; Version = '1.0.0'; Backup = @('Sample Pubs', 'Sample Endorse', 'Sample Recs (Form 1)'); Start = ''
  Restore = @{ TestSites = @('fake'); Pause = $pause } }
$b = Invoke-Backup $base $null
Assert-Case 'backup: a list title with parentheses is saved under its own name (R39)' ($b.State -eq 'done' -and (Test-Path -LiteralPath (Join-Path $b.Path 'Sample Recs (Form 1).json')))
$sets = @(Get-BackupSet $base)
Assert-Case 'restore: the backup list names the backup and its 3 lists' ($sets.Count -eq 1 -and $sets[0].Lists -eq 3 -and $sets[0].Path -eq $b.Path)
# The site after the backup: P2 deleted to the Recycle Bin, P3 and E2 deleted for good, P4 made after the backup.
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
$s.bin = @(@{ list = 'Sample Pubs'; row = ($s.items.'Sample Pubs' | Where-Object { $_.ID -eq 2 }) })
$s.items.'Sample Pubs' = @(($s.items.'Sample Pubs' | Where-Object { $_.ID -eq 1 }), @{ ID = 4; Title = 'P4' }); $s.meta.'Sample Pubs'.next = 5
$s.items.'Sample Endorse' = @($s.items.'Sample Endorse' | Where-Object { $_.ID -eq 1 })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$before = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw
# A site that is not a test site: refused, before the sign-in, nothing written.
$script:app.Restore = @{ TestSites = @('other'); Pause = $pause }
$pl = Invoke-RestorePlan $base $b.Path $null
Assert-Case 'restore: a site that is not a test site is refused' ($pl.State -eq 'refused' -and ($pl.Lines -join ' ') -like '*only on a test site*')
$w = Invoke-Restore $base $b.Path @{ State = 'plan'; Missing = 1; Expect = '1:1'; Plan = @{} } $null
Assert-Case 'restore: the write refuses a site that is not a test site' ($w.State -eq 'refused' -and (Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw) -eq $before)
$script:app.Restore = @{ TestSites = @('Fake'); Pause = $pause }   # site names compare without case
# The dry run: counts per list, nothing written.
$pl = Invoke-RestorePlan $base $b.Path $null; $all = $pl.Lines -join ' '
Assert-Case 'restore: the dry run gives the total' ($pl.State -eq 'plan' -and $pl.Missing -eq 3 -and
  $pl.Lines[0] -like 'Dry run: 3 rows would come back (1 from the Recycle Bin, 2 as new rows). Nothing was written.')
$wantP = '*"Sample Pubs": 3 in the backup, 2 on the list now. Would put back 2 (1 from the Recycle Bin, 1 as new rows). 1 made after the backup stay.*'
Assert-Case 'restore: the dry run counts each list' ($all -like $wantP -and
  $all -like '*"Sample Endorse": 2 in the backup, 1 on the list now. Would put back 1 (0 from the Recycle Bin, 1 as new rows).*' -and
  $all -like '*"Sample Recs (Form 1)": 1 in the backup, 1 on the list now. Would put back 0*')
Assert-Case 'restore: the dry run writes nothing' ((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw) -eq $before)
Assert-Case 'restore: the dry run lines hold no row value' ($all -notmatch 'P2|P3|E2|Sample Person|example\.invalid')
# The site changes after the dry run: the write stops before any row (the fresh backup is still made).
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.items.'Sample Endorse' = @(); $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
Assert-Case 'restore: a site that changed after the dry run gets no row' ($w.State -eq 'changed' -and @($s.items.'Sample Pubs').Count -eq 2 -and @($s.bin).Count -eq 1 -and @($s.log).Count -eq 0)
$s.items.'Sample Endorse' = @(@{ ID = 1; Title = 'E1'; Pub = '2;#P2' }); $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
# The pause switch is on already: no row is written.
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.rows.RestorePause = 'On'; $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
Assert-Case 'restore: a pause switch that is on already stops it' ($w.State -eq 'failed' -and ($w.Lines[0]) -like '*pause switch is on already*' -and @($s.items.'Sample Pubs').Count -eq 2)
$s.rows.RestorePause = 'Off'; $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
# The write.
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $pu = @($s.items.'Sample Pubs'); $en = @($s.items.'Sample Endorse')
Assert-Case 'restore: the write is done and says so' ($w.State -eq 'done' -and $w.Lines[0] -eq 'Restore put back 3 of 3 rows. Rows on the lists were not changed.')
Assert-Case 'restore: a fresh backup is saved first (R3)' ($w.Path -and $w.Path -ne $b.Path -and (Test-Path -LiteralPath (Join-Path $w.Path 'Sample Pubs.json')))
$p2 = @($pu | Where-Object { $_.ID -eq 2 })[0]; $p3 = @($pu | Where-Object { $_.Title -eq 'P3' })[0]
Assert-Case 'restore: a row in the Recycle Bin comes back with its own ID (R1)' ($p2 -and $p2.Title -eq 'P2' -and @($s.bin).Count -eq 0)
Assert-Case 'restore: a row gone for good comes back as a new row' ($p3 -and $p3.ID -eq 5 -and $pu.Count -eq 4)
Assert-Case 'restore: a person, a link and a date go back in the form PnP takes' ($p3.Link -eq 'https://example.invalid/p3, Page' -and ([datetime]$p3.Due).ToUniversalTime().Hour -eq 12)
$e2 = @($en | Where-Object { $_.Title -eq 'E2' })[0]
Assert-Case 'restore: a lookup to a row made new points to its new ID (R5)' ($e2 -and [int]$e2.Pub -eq 5)
Assert-Case 'restore: a row made after the backup stays' (@($pu | Where-Object { $_.Title -eq 'P4' }).Count -eq 1)
Assert-Case 'restore: a row on the list is not changed' ([string]@($en | Where-Object { $_.ID -eq 1 })[0].Pub -eq '2;#P2')
Assert-Case 'restore: the pause switch goes on, then back (R2)' ((@($s.log) -join ',') -eq 'On,Off' -and $s.rows.RestorePause -eq 'Off' -and
  ($w.Lines -join ' ') -like "*pause switch is back as it was*")
Assert-Case 'restore: each list gets its count line' (($w.Lines -join ' ') -like '*PASS: "Sample Pubs": 1 back from the Recycle Bin, 1 made new; 4 rows on the list now*' -and
  ($w.Lines -join ' ') -like '*PASS: "Sample Endorse": 0 back from the Recycle Bin, 1 made new; 2 rows on the list now*')
# A second run has nothing to put back.
$pl = Invoke-RestorePlan $base $b.Path $null
Assert-Case 'restore: a second dry run finds nothing missing' ($pl.State -eq 'plan' -and $pl.Missing -eq 0)
$w = Invoke-Restore $base $b.Path $pl $null
Assert-Case 'restore: with nothing missing the write does nothing' ($w.State -eq 'failed' -and $w.Lines[0] -eq 'There are no rows to put back.')
# A Recycle Bin that cannot be read: the dry run says so (the rows would come back as new rows).
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s | Add-Member -NotePropertyName binError -NotePropertyValue $true
$s.items.'Sample Recs (Form 1)' = @(); $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $b.Path $null
Assert-Case 'restore: a Recycle Bin that cannot be read is named' ($pl.State -eq 'plan' -and $pl.Missing -eq 1 -and ($pl.Lines -join ' ') -like '*Recycle Bin could not be read*')
# An app that does not name Restore: refused.
$script:app.Restore = $null; $t = Test-RestoreSite $base
Assert-Case 'restore: an app that does not name it cannot run it' (-not $t.Ok -and $t.Lines[0] -like '*does not use Restore*')

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
