# RADE test: the Maintenance tools Diagnose, Back up and Restore (engine/ps/13-maintenance.ps1; Uninstall and Remove RADE in
# part 2, tools_unit_uninstall.ps1, run at the end), on the engine parts themselves
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
foreach ($p in '01-base', '02-config', '03-files', '04-steps', '05-installed', '07-checks', '16-site-scripts', '08-saved-checks', '13-maintenance', '14-restore',
  '15-restore-run', '12-resume') { . (Join-Path $root ('engine/ps/' + $p + '.ps1')) }
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
# The local test-site mark (engine-v32): "testSites": "local" needs the mark of this site on this computer.
$script:app.Restore = @{ TestSites = @(); Local = $true; Pause = $pause }; $mk = Get-RestoreMarkFile $base
if (Test-Path -LiteralPath $mk) { Remove-Item -LiteralPath $mk -Force }
$t = Test-RestoreSite $base; $pl = Invoke-RestorePlan $base $b.Path $null
Assert-Case 'restore: a local app with no mark is refused and asks for the mark' (-not $t.Ok -and $t.NeedMark -and $t.Name -eq 'fake' -and
  $pl.State -eq 'refused' -and ($pl.Lines -join ' ') -like '*marked as a test site on this computer*')
$w = Invoke-Restore $base $b.Path @{ State = 'plan'; Missing = 1; Expect = '1:1'; Plan = @{} } $null
Assert-Case 'restore: the write refuses a site with no mark' ($w.State -eq 'refused' -and (Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw) -eq $before)
Save-RestoreMark $base 'other'; $t = Test-RestoreSite $base
Assert-Case 'restore: the mark of another site does not count' (-not $t.Ok -and $t.NeedMark)
$script:app.Restore = @{ TestSites = @('other'); Local = $false; Pause = $pause }; $t = Test-RestoreSite $base
Assert-Case 'restore: a list of names ignores the mark' (-not $t.Ok -and -not $t.NeedMark -and ($t.Lines -join ' ') -like '*only on a test site that the app names*')
$script:app.Restore = @{ TestSites = @(); Local = $true; Pause = $pause }; Save-RestoreMark $base 'FAKE'; $t = Test-RestoreSite $base
Assert-Case 'restore: the mark of this site lets Restore run (without case)' ($t.Ok -and $t.Name -eq 'fake')
Assert-Case 'restore: the mark is in Config next to the site address' ((Split-Path -Parent $mk) -eq (Split-Path -Parent (Get-ConfigFile $base '@@PREFIX@@-site.txt')) -and
  (Get-RestoreMark $base) -eq 'FAKE')
$n = Get-RestoreMarkNote $base
Assert-Case 'restore: Diagnose notes a marked site, with no site name (engine-v33)' ($n.State -eq 'NOTE' -and $n.Text -like '*is marked as a test site*' -and $n.Text -notlike '*fake*')
Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake3'; $t = Test-RestoreSite $base; $n = Get-RestoreMarkNote $base; Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake'
Assert-Case 'restore: a new site address needs a new mark' (-not $t.Ok -and $t.NeedMark -and $t.Name -eq 'fake3')
Assert-Case 'restore: Diagnose notes a mark of another site' ($n.State -eq 'NOTE' -and $n.Text -like '*for another site*')
Clear-RestoreMark $base; $t = Test-RestoreSite $base; $n = Get-RestoreMarkNote $base
Assert-Case 'restore: a removed mark makes Restore ask again (engine-v33)' (-not (Test-Path -LiteralPath $mk) -and -not $t.Ok -and $t.NeedMark)
Assert-Case 'restore: Diagnose notes a site with no mark' ($n.State -eq 'NOTE' -and $n.Text -like '*not marked*')
Clear-RestoreMark $base   # no file: nothing to do, no error
$script:app.Restore = @{ TestSites = @('fake'); Local = $false; Pause = $pause }
Assert-Case 'restore: Diagnose has no mark line for a list of names' ($null -eq (Get-RestoreMarkNote $base))
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
# The same count but other rows missing after the dry run: the write stops too (the hash of the missing rows).
$pl = Invoke-RestorePlan $base $b.Path $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
$s.items.'Sample Endorse' = @(@{ ID = 2; Title = 'E2'; Pub = '3;#P3' }); $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
Assert-Case 'restore: other rows missing with the same count stop the write' ($w.State -eq 'changed' -and @($s.items.'Sample Pubs').Count -eq 2 -and @($s.log).Count -eq 0)
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
# Another backup that holds the same rows (a copy of the first): it finds nothing missing either; the record of re-made
# rows is one for each site (Backups\~restore-map-<site hash>.json), not one per backup (review of PR 151).
$b2 = $b.Path + '-copy'; Copy-Item -LiteralPath $b.Path -Destination $b2 -Recurse
$pl = Invoke-RestorePlan $base $b2 $null
Assert-Case 'restore: another backup of the same rows does not make a re-made row again' ($pl.State -eq 'plan' -and $pl.Missing -eq 0 -and
  @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Filter '~restore-map-*.json').Count -eq 1)
Remove-Item -LiteralPath $b2 -Recurse -Force
Assert-Case 'restore: the record is one file for each site, not in a backup folder' (@(Get-ChildItem -LiteralPath $b.Path -Filter '~restore-map*').Count -eq 0 -and
  @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Filter '~restore-map-*.json').Count -eq 1)
# A chain (second review of PR 151): P3 (3) was made as 5; a new backup holds 5; 5 is deleted for good and made again as 6
# from that backup; the first backup then finds P3 on the list (3 to 5 to 6) and makes nothing.
Start-Sleep -Seconds 1; $bB = Invoke-Backup $base $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.ID -ne 5 })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $bB.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $bB.Path $pl $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
$p3 = @($s.items.'Sample Pubs' | Where-Object { $_.Title -eq 'P3' })
$pl = Invoke-RestorePlan $base $b.Path $null; $pubLine = @($pl.Lines | Where-Object { $_ -like '"Sample Pubs"*' })[0]
Assert-Case 'restore: a row re-made twice is followed to its newest ID (no third copy)' ($w.State -eq 'done' -and $p3.Count -eq 1 -and $p3[0].ID -eq 6 -and
  $pubLine -like '*Would put back 0*')
# The reverse order (review 3 of PR 151): 6 is deleted for good; Restore from the first backup makes P3 again (7); the
# second backup (which holds 5) then makes nothing: 3, 5, 6 and 7 are one row.
# Returns the rows of Sample Pubs titled P3 on the fake site. Takes nothing.
function Get-P3 { return @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).items.'Sample Pubs' | Where-Object { $_.Title -eq 'P3' }) }
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.ID -ne 6 })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$pl = Invoke-RestorePlan $base $bB.Path $null; $p3 = Get-P3
Assert-Case 'restore: the reverse order makes no second copy' ($w.State -eq 'done' -and $p3.Count -eq 1 -and $p3[0].ID -eq 7 -and $pl.Missing -eq 0)
# The Recycle Bin holds a later ID of the row (7): Restore from the second backup brings 7 back, it makes no new row.
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $row = @($s.items.'Sample Pubs' | Where-Object { $_.ID -eq 7 })[0]
$s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.ID -ne 7 }); $s.bin = @(@{ list = 'Sample Pubs'; row = $row })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $bB.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $bB.Path $pl $null; $p3 = Get-P3
Assert-Case 'restore: a later ID of the row in the Recycle Bin comes back, no new row' ($pl.Missing -eq 1 -and $w.State -eq 'done' -and $p3.Count -eq 1 -and $p3[0].ID -eq 7 -and
  @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).bin).Count -eq 0)
# Another test site: the record of the first site does not count there (its IDs are not this site's).
Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake2'; $script:app.Restore = @{ TestSites = @('fake', 'fake2'); Pause = $pause }
$pl = Invoke-RestorePlan $base $b.Path $null
Assert-Case "restore: another site does not use the first site's record" ($pl.State -eq 'plan' -and $pl.Missing -ge 1)
Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake'
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
# A write that works but reports an error (review 4 of PR 151): the pending mark stays, so no later run makes it again.
$script:app.Restore = @{ TestSites = @('fake'); Pause = $pause }
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.binError = $false; $s | Add-Member -NotePropertyName addThrow -NotePropertyValue $true
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.addThrow = $false; $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl2 = Invoke-RestorePlan $base $b.Path $null; $recs = @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).items.'Sample Recs (Form 1)')
Assert-Case 'restore: a write that reports an error is not made again' ($pl.Missing -eq 1 -and $w.State -eq 'failed' -and ($w.Lines -join ' ') -like '*not confirmed*' -and
  $pl2.Missing -eq 0 -and ($pl2.Lines -join ' ') -like '*1 row(s) are left out: an earlier Restore wrote them but did not confirm it*' -and $recs.Count -eq 1)
# The record cannot be saved: no row is written, and the result says why.
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.ID -ne 1 })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$mf = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Filter '~restore-map-*.json')[0].FullName; $blk = $mf + '.new'; $null = New-Item -ItemType Directory -Path $blk
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null
$p1 = @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).items.'Sample Pubs' | Where-Object { $_.Title -eq 'P1' })
Assert-Case 'restore: the lists after a stop keep their count lines' (@($w.Lines | Where-Object { $_ -like '*: no result*' }).Count -eq 0 -and
  @($w.Lines | Where-Object { $_ -like 'PASS: "Sample Endorse":*' }).Count -eq 1)
Assert-Case 'restore: a record that cannot be saved stops before the row' ($pl.Missing -eq 1 -and $w.State -eq 'failed' -and $p1.Count -eq 0 -and
  ($w.Lines -join ' ') -like '*record of re-made rows could not be saved*')
Remove-Item -LiteralPath $blk -Recurse -Force
# A saved value that cannot be read (a bad date): that row is not written and gets no mark; a row added on the site
# between the dry run and the write gives no false finding (the count check starts from the write's own read).
$b3 = $b.Path + '-bad'; Copy-Item -LiteralPath $b.Path -Destination $b3 -Recurse
$pj = Join-Path $b3 'Sample Pubs.json'; $rows = @(Get-Content -LiteralPath $pj -Raw | ConvertFrom-Json)
foreach ($row in $rows) { if ($row.ID -eq 1) { $row | Add-Member -Force -NotePropertyName Due -NotePropertyValue 'not a date' } }
ConvertTo-Json -InputObject $rows -Depth 4 | Set-Content -LiteralPath $pj
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.ID -ne 2 })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP   # P2 is missing too: the row after the bad one
$pl = Invoke-RestorePlan $base $b3 $null
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.items.'Sample Endorse' = @($s.items.'Sample Endorse') + @(@{ ID = 99; Title = 'E99' })
$s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b3 $pl $null; $all = $w.Lines -join ' '
$pubs = @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).items.'Sample Pubs'); $p1 = @($pubs | Where-Object { $_.Title -eq 'P1' })
$pl2 = Invoke-RestorePlan $base $b3 $null
Assert-Case 'restore: a bad saved value skips that row only, with no mark' ($pl.Missing -eq 2 -and $w.State -eq 'failed' -and $p1.Count -eq 0 -and $pl2.Missing -eq 1 -and
  $all -like '*1 row(s) not written: a saved value could not be read*' -and $all -notlike '*not confirmed*')
Assert-Case 'restore: the row after a bad one is still written' (@($pubs | Where-Object { $_.Title -eq 'P2' }).Count -eq 1)
Assert-Case 'restore: a row added after the dry run gives no false finding' ($all -like '*PASS: "Sample Endorse":*' -and $all -notlike '*FINDING: "Sample Endorse"*')
Remove-Item -LiteralPath $b3 -Recurse -Force
# An empty record file stops the dry run (it is never read as "no record").
$keepMap = Get-Content -LiteralPath $mf -Raw; Set-Content -LiteralPath $mf -Value 'null'; $pl = Invoke-RestorePlan $base $b.Path $null; Set-Content -LiteralPath $mf -Value $keepMap -NoNewline
Assert-Case 'restore: an empty record stops the dry run' ($pl.State -eq 'failed' -and ($pl.Lines[0]) -like '*could not be read*')
# E2 (R42; the Administrator, 2026-11-21): a Recycle Bin row that cannot be restored is made new, and the card says so
# as a FINDING with the error type (never a PASS: the row has a new row number).
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $row = @($s.items.'Sample Pubs' | Where-Object { $_.Title -eq 'P2' })[0]
$s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.Title -ne 'P2' }); $s.bin = @(@{ list = 'Sample Pubs'; row = $row })
$s | Add-Member -Force -NotePropertyName binRestoreError -NotePropertyValue $true; $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null; $all = $w.Lines -join ' '
$p2 = @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).items.'Sample Pubs' | Where-Object { $_.Title -eq 'P2' })
Assert-Case 'restore: a Recycle Bin row that fails is a FINDING with its error type, not a PASS (E2)' ($pl.Lines[0] -like '*(1 from the Recycle Bin,*' -and $w.State -eq 'failed' -and
  $all -like '*FINDING: "Sample Pubs": 0 back from the Recycle Bin, 2 made new;*' -and
  $all -like '*1 row(s) did not come back from the Recycle Bin (InvalidOperationException), so Restore made them as new rows with new row numbers*' -and
  $p2.Count -eq 1 -and [int]$p2[0].ID -ne [int]$row.ID)
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.binRestoreError = $false; $s.bin = @(); $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
# A restore that reports an error but worked (review of PR 166): the row is back with its own ID, counted as back, no BINERR.
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $row = @($s.items.'Sample Pubs' | Where-Object { $_.Title -eq 'P2' })[0]
$s.items.'Sample Pubs' = @($s.items.'Sample Pubs' | Where-Object { $_.Title -ne 'P2' }); $s.bin = @(@{ list = 'Sample Pubs'; row = $row })
$s | Add-Member -Force -NotePropertyName binRestoreLies -NotePropertyValue $true; $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
$pl = Invoke-RestorePlan $base $b.Path $null; Start-Sleep -Seconds 1; $w = Invoke-Restore $base $b.Path $pl $null; $all = $w.Lines -join ' '
$p2 = @((Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json).items.'Sample Pubs' | Where-Object { $_.Title -eq 'P2' })
Assert-Case 'restore: a Recycle Bin restore that throws but worked counts as back, not made new' ($all -like '*"Sample Pubs": 1 back from the Recycle Bin,*' -and
  $all -notlike '*did not come back from the Recycle Bin*' -and $p2.Count -eq 1 -and [int]$p2[0].ID -eq [int]$row.ID)
$s = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json; $s.binRestoreLies = $false; $s | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP

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
# engine-v33: an app with "testSites": "local" gets one NOTE line about the mark; it is not a finding.
$f0 = $d.Findings; $script:app.Restore = @{ TestSites = @(); Local = $true; Pause = $null }; $d = Invoke-Diagnose $base $null; $script:app.Restore = $null
Assert-Case 'diagnose: the mark line is a NOTE, not a finding' ($d.Findings -eq $f0 -and @($d.Lines | Where-Object { $_ -like 'NOTE: Restore test-site mark:*' }).Count -eq 1)
# D0: the app's checks run again; a check that runs on its own gives one line with its state.
$script:appChecks = @('ps'); $d = Invoke-Diagnose $base $null; $all = $d.Lines -join ' '
Assert-Case 'diagnose: D0 runs the app checks again' ($all -match '(PASS|FINDING): [^:]+: (PASSED|WARNING|FAILED|NOT RUN)')
# The child scripts are PowerShell in here-strings: the parser reads each one (code standard C10 and X2).
$kids = @(@{ N = 'Back up'; T = $backupScript }, @{ N = 'Restore'; T = $restoreScript }, @{ N = 'Rights'; T = $rightsScript }, @{ N = 'Marker'; T = $markerScript })
foreach ($c in $kids) { $perr = $null
  $null = [System.Management.Automation.Language.Parser]::ParseInput($c.T, [ref]$null, [ref]$perr)
  Assert-Case ('child script parses: ' + $c.N) (@($perr).Count -eq 0)
  # E3, engine-v44: each child script that signs in holds the one sign-in block (no marker left) and signs in through it.
  $conn = $c.T.IndexOf('Connect-RadeSite $Site')
  Assert-Case ('sign-in block in: ' + $c.N) ($c.T.Contains($signInSize.TrimEnd()) -and -not $c.T.Contains('# <RADE sign-in window size>') -and $conn -gt $c.T.IndexOf('function Connect-RadeSite')) }
# engine-v44 (the PFM, 2026-11-26): RADE never touches the CAC sign-in window. The block keeps its two marker lines (an
# app's build finds it by them), has no size watch and no SetWindowPos, and Connect-RadeSite still prints its lines.
Assert-Case 'sign-in block (engine-v44): the marker lines stay; no size watch, no SetWindowPos, no RADE_SIGNIN_WATCH' (
  $signInSize -match '(?m)^# ---- RADE sign-in window size \(start' -and $signInSize -match '(?m)^# ---- RADE sign-in window size \(end\)' -and
  $signInSize -notmatch 'SetWindowPos|function Start-SignInSize|function Stop-SignInSize|RADE_SIGNIN_WATCH|Size2' -and $signInSize -notmatch 'EnumWindows\(')
$sbErr = $null; $cLines = @()
try { . ([scriptblock]::Create($signInSize))
  # A stand-in for the PnP sign-in that returns at once (this case tests the lines only). Takes the address; gives nothing.
  function Connect-PnPOnline { [CmdletBinding()] param($Url, [switch]$UseWebLogin) }
  $cLines = @(Connect-RadeSite 'https://usaf.dps.mil/sites/fake'); Remove-Item Function:\Connect-PnPOnline } catch { $sbErr = $_ }
# engine-v46 (90-161.Z R45 finding 2): the process becomes DPI-aware before the sign-in and says so (not Windows here: no).
Assert-Case 'sign-in block (engine-v44, v46): Connect-RadeSite prints STAGE signin, SIGNIN-DPI aware=, SIGNIN seconds=N and STAGE none' ($null -eq $sbErr -and
  @($cLines).Count -eq 4 -and $cLines[0] -eq 'STAGE signin' -and $cLines[1] -match '^SIGNIN-DPI aware=(yes|was|no|off)$' -and $cLines[2] -match '^SIGNIN seconds=\d+$' -and $cLines[3] -eq 'STAGE none')
# engine-v46 (90-161.Z R45 finding 1): a script policy block is a result with no PASS or SKIP line and an error that says
# Windows did not load the script; a step that printed a line, or failed another way, is not one. The policy line names
# each scope. RADE_SIGNIN_DPI=0 turns the DPI setting off.
$pb1 = Test-PolicyBlock @{ Pass = 0; Skip = 0; Err = "File C:\x.ps1 cannot be`nloaded because running scripts is disabled on this system.`n" }
$pb2 = Test-PolicyBlock @{ Pass = 1; Skip = 0; Err = 'running scripts is disabled' }
$pb3 = Test-PolicyBlock @{ Pass = 0; Skip = 0; Err = 'Access to the path is denied. UnauthorizedAccess' }
$pl = Get-PolicyLine; $env:RADE_SIGNIN_DPI = '0'; $dOff = Set-SignInDpiAware; Remove-Item Env:\RADE_SIGNIN_DPI
Assert-Case 'policy block (engine-v46): found only for a script Windows did not load; the policy line; the DPI switch off' ($pb1 -and -not $pb2 -and -not $pb3 -and
  $pl -match '^Policy: .+; in effect: \S+$' -and $dOff -eq 'SIGNIN-DPI aware=off')
# R43 E4 (the PFM, 2026-11-25): the rights check gives its sign-in time (engine-v44: no watch= part).
$script:app = @{ Name = 'Sample app'; Version = '1.0.0'; Marker = $null }
$env:RADE_SIGNIN_TEST = '1'; $sr1 = Get-SiteRightsCheck $base 'https://usaf.dps.mil/sites/fake' $null; $env:RADE_SIGNIN_TEST = $null
Assert-Case 'sign-in time: the rights check detail ends with "SIGNIN seconds=N host=..."' ([string]$sr1.Detail -match 'SIGNIN seconds=\d+ host=\S+$')
# engine-v43 S1, S2 (the PFM, 2026-11-26): "STAGE none" ends the timed stage; a stage past its limit stops the child and is
# named; the window report helper compiles (its lines need Windows: here it prints none).
$st1 = Invoke-ChildScript "'STAGE signin'`r`n'STAGE none'`r`nStart-Sleep -Seconds 3`r`n'RESULT ok'`r`n" '' 60 $null 1
$st2 = Invoke-ChildScript "'STAGE signin'`r`nStart-Sleep -Seconds 20`r`n'RESULT ok'`r`n" '' 60 $null 2
$env:RADE_SIGNIN_TEST = '1'; $rpErr = $null; try { Start-SignInReport; Stop-SignInReport } catch { $rpErr = $_ }; $env:RADE_SIGNIN_TEST = $null
Assert-Case 'sign-in stage (engine-v43): STAGE none ends the limit; a frozen sign-in stops and is named; the report compiles' (
  -not $st1.Stage -and @($st1.Lines) -contains 'RESULT ok' -and $st2.Stage -eq 'signin' -and @($st2.Lines) -notcontains 'RESULT ok' -and -not $rpErr -and [bool]('RadeSignIn.Report1' -as [type]))
# Uninstall and Remove RADE (engine-v40): their cases are in tools_unit_uninstall.ps1, run here in this scope (they use the fake site and the app above).
. (Join-Path $PSScriptRoot 'tools_unit_uninstall.ps1')
Write-Host ('TOOLS-UNIT pass=' + $script:pass + ' fail=' + $script:fail)
