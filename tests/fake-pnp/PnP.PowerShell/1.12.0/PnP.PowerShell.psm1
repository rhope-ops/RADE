# A fake PnP.PowerShell for tests/engine_test.sh (no SharePoint, no network). Its state is the JSON file named by
# RADE_FAKE_PNP: { "admin": true, "rights": true, "list": true, "rows": { "<Title>": "<value>" }, "items": { "<list>": [ { field: value } ] } }.
if (-not ('Microsoft.SharePoint.Client.PermissionKind' -as [type])) {
  Add-Type -TypeDefinition 'namespace Microsoft.SharePoint.Client { public enum PermissionKind { ViewListItems, AddListItems, EditListItems, ManageLists, ManageWeb, ManagePermissions } }'
}
function Get-FakeState { return (Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json) }
function Connect-PnPOnline { param([string]$Url, [switch]$UseWebLogin) if ($Url -notlike 'https://usaf.dps.mil/sites/*') { throw 'wrong host' } }
function Get-PnPWeb {
  param([string[]]$Includes)
  $s = Get-FakeState
  $perm = New-Object psobject | Add-Member -PassThru -MemberType ScriptMethod -Name Has -Value ([scriptblock]::Create('param($k) return ' + $(if ($s.rights) { '$true' } else { '$false' })))
  return [pscustomobject]@{ EffectiveBasePermissions = $perm; CurrentUser = [pscustomobject]@{ IsSiteAdmin = [bool]$s.admin } }
}
function Get-PnPList { param([string]$Identity) if ((Get-FakeState).listError) { throw "list read failed" }; if ((Get-FakeState).list) { return [pscustomobject]@{ Title = $Identity } } }
function Get-PnPListItem {
  param($List, [string]$Query, [int]$PageSize)
  $s = Get-FakeState; $i = 0
  # Back up (no query): the rows of "items"."<list>", each with FieldValues as SharePoint gives them; a list not there throws.
  if (-not $Query) { $rows = $null; if ($s.items) { $rows = $s.items.PSObject.Properties[[string]$List] }
    if (-not $rows) { throw 'list not found' }
    return @(foreach ($r in @($rows.Value)) { $d = New-Object 'System.Collections.Generic.Dictionary[string,object]'; foreach ($q in $r.PSObject.Properties) { $d[$q.Name] = $q.Value }; [pscustomobject]@{ FieldValues = $d } }) }
  foreach ($p in @($s.rows.PSObject.Properties)) { $i++; if ($Query -like ("*>" + $p.Name + "<*")) { $h = @{ Title = $p.Name; SettingValue = [string]$p.Value }; $h | Add-Member -NotePropertyName Id -NotePropertyValue $i; return , $h } }
}
function Set-FakeRow([hashtable]$Values, [string]$Title) {
  $s = Get-FakeState
  $s.rows | Add-Member -Force -NotePropertyName $Title -NotePropertyValue ([string]$Values['SettingValue'])
  $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:RADE_FAKE_PNP
}
function Add-PnPListItem { param($List, [hashtable]$Values) Set-FakeRow $Values ([string]$Values['Title']) }
function Set-PnPListItem { param($List, $Identity, [hashtable]$Values) Set-FakeRow $Values ([string]@((Get-FakeState).rows.PSObject.Properties)[[int]$Identity - 1].Name) }
