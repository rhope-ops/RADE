# RADE engine part 10, the window slot: the window parts (engine/ps/window) are put in here when the bundle
# is built. If the window cannot open, the round falls back to text mode (11-text-mode.ps1).
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

if ($gui) {
  try {
    # @@WINDOW@@
  } catch {
    $gui = $false; $script:noWindowWhy = [string]$_.Exception.Message
    if ($_.InvocationInfo) { $script:noWindowWhy += ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')' }
    $shown = $script:noWindowWhy
    if ($env:USERPROFILE) { $shown = $shown -replace [regex]::Escape([string]$env:USERPROFILE), '<USERPROFILE>' }
    Write-Host ('No window could open (' + (ConvertTo-Masked $shown) + '). The round runs in text mode.')
  }
}
