# A fake PnP.PowerShell for tests/engine_test.sh (no SharePoint, no network). Its state is the JSON file named by
# RADE_FAKE_PNP: { "admin": true, "rights": true, "list": true, "rows": { "<Title>": "<value>" }, "items": { "<list>": [ { field: value } ] } }.
# Restore (engine-v31) adds "meta": { "<list>": { "id": "<guid>", "url": "sites/x/Lists/y", "next": <next ID>, "fields": [ field ] } },
# "bin": [ { "list": "<list>", "row": { "ID": n, ... } } ] (the Recycle Bin) and "log" (each Set-PnPListItem value, in order).
# A list in "meta" takes new rows into "items" with the next ID; fake data only.
if (-not ('Microsoft.SharePoint.Client.PermissionKind' -as [type])) {
  Add-Type -TypeDefinition 'namespace Microsoft.SharePoint.Client { public enum PermissionKind { ViewListItems, AddListItems, EditListItems, ManageLists, ManageWeb, ManagePermissions } }'
}
function Get-FakeState { return (Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json) }
# Saves the fake state. Takes the state.
function Save-FakeState($S) { $S | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:RADE_FAKE_PNP }
# The "meta" of a list of the Restore tests, or $null. Takes the state and the list title.
function Get-FakeMeta($S, [string]$List) { if ($S.meta) { $m = $S.meta.PSObject.Properties[$List]; if ($m) { return $m.Value } }; return $null }
function Connect-PnPOnline { param([string]$Url, [switch]$UseWebLogin) if ($Url -notlike 'https://usaf.dps.mil/sites/*') { throw 'wrong host' } }
function Get-PnPWeb {
  param([string[]]$Includes)
  $s = Get-FakeState
  $perm = New-Object psobject | Add-Member -PassThru -MemberType ScriptMethod -Name Has -Value ([scriptblock]::Create('param($k) return ' + $(if ($s.rights) { '$true' } else { '$false' })))
  return [pscustomobject]@{ EffectiveBasePermissions = $perm; CurrentUser = [pscustomobject]@{ IsSiteAdmin = [bool]$s.admin } }
}
function Get-PnPList { param([string]$Identity, [string[]]$Includes)
  $s = Get-FakeState
  if ($s.meta) { $m = Get-FakeMeta $s $Identity; if (-not $m) { return $null }
    return [pscustomobject]@{ Title = $Identity; Id = [guid]$m.id; RootFolder = [pscustomobject]@{ ServerRelativeUrl = '/' + $m.url } } }
  if ((Get-FakeState).listError) { throw "list read failed" }; if ((Get-FakeState).list) { return [pscustomobject]@{ Title = $Identity } } }
function Get-PnPListItem {
  param($List, [string]$Query, [int]$PageSize, [string[]]$Fields)
  $s = Get-FakeState; $i = 0
  # Back up (no query): the rows of "items"."<list>", each with FieldValues as SharePoint gives them; a list not there throws.
  if (-not $Query) { $rows = $null; if ($s.items) { $rows = $s.items.PSObject.Properties[[string]$List] }
    if (-not $rows) { throw 'list not found' }
    return @(foreach ($r in @($rows.Value)) { $d = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        foreach ($q in $r.PSObject.Properties) { $d[$q.Name] = $q.Value }; [pscustomobject]@{ Id = $r.ID; FieldValues = $d } }) }
  foreach ($p in @($s.rows.PSObject.Properties)) { $i++; if ($Query -like ("*>" + $p.Name + "<*")) { $h = @{ Title = $p.Name; SettingValue = [string]$p.Value }; $h | Add-Member -NotePropertyName Id -NotePropertyValue $i; return , $h } }
}
function Set-FakeRow([hashtable]$Values, [string]$Title) {
  $s = Get-FakeState
  $s.rows | Add-Member -Force -NotePropertyName $Title -NotePropertyValue ([string]$Values['SettingValue'])
  if ($s.PSObject.Properties['log']) { $s.log = @($s.log) + @([string]$Values['SettingValue']) }
  Save-FakeState $s
}
function Add-PnPListItem { param($List, [hashtable]$Values)
  $s = Get-FakeState; $m = Get-FakeMeta $s ([string]$List)
  if (-not $m) { Set-FakeRow $Values ([string]$Values['Title']); return }
  # A list of the Restore tests: the row gets the next ID (SharePoint never reuses an ID); each value is kept as given.
  $id = [int]$m.next; $m.next = $id + 1; $row = [ordered]@{ ID = $id }; foreach ($k in $Values.Keys) { $row[$k] = $Values[$k] }
  $s.items.([string]$List) = @($s.items.([string]$List)) + @([pscustomobject]$row); Save-FakeState $s
  return [pscustomobject]@{ Id = $id } }
# The fields of a list in "meta". Takes the list title.
function Get-PnPField { param($List) $m = Get-FakeMeta (Get-FakeState) ([string]$List); if (-not $m) { throw 'list not found' }
  return @(foreach ($f in @($m.fields)) { [pscustomobject]@{ InternalName = $f.InternalName; TypeAsString = $f.TypeAsString
      ReadOnlyField = [bool]$f.ReadOnlyField; Hidden = [bool]$f.Hidden; SchemaXml = [string]$f.SchemaXml } }) }
# The Recycle Bin ("bin") as SharePoint lists it: ItemType, LeafName "<ID>_.000", DirName; "binError" throws.
function Get-PnPRecycleBinItem { param([int]$RowLimit) $s = Get-FakeState; if ($s.binError) { throw 'access denied' }; $k = 0
  return @(foreach ($b in @($s.bin)) { $k++; $m = Get-FakeMeta $s ([string]$b.list)
    [pscustomobject]@{ Id = $k; ItemType = 'ListItem'; LeafName = ([string]$b.row.ID + '_.000'); DirName = [string]$m.url; FakeList = [string]$b.list; FakeId = [int]$b.row.ID } }) }
# Moves one row from the Recycle Bin back to its list, with its own ID. Takes the bin item.
function Restore-PnPRecycleBinItem { param($Identity, [switch]$Force) $s = Get-FakeState
  $b = @($s.bin | Where-Object { $_.list -eq $Identity.FakeList -and [int]$_.row.ID -eq $Identity.FakeId })[0]; if (-not $b) { throw 'not in the bin' }
  $s.items.([string]$b.list) = @($s.items.([string]$b.list)) + @($b.row); $s.bin = @($s.bin | Where-Object { $_ -ne $b }); Save-FakeState $s }
function Set-PnPListItem { param($List, $Identity, [hashtable]$Values) Set-FakeRow $Values ([string]@((Get-FakeState).rows.PSObject.Properties)[[int]$Identity - 1].Name) }
