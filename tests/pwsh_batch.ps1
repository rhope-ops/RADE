# Runs the text-mode rounds of one test group in one pwsh process (tests/engine_test.sh "psrun"; bloat audit P8 follow-up,
# 2026-11-16). A new pwsh costs about 2 s of CPU for each round; one process per group pays it once.
# Reads one request per line from the FIFO $Requests: FILE <tab> INPUT FILE <tab> OUTPUT FILE [<tab> NAME=VALUE ...], and
# writes the exit code as one line to the FIFO $Replies. Each round gets what "pwsh -NoProfile -File FILE < INPUT > OUTPUT
# 2>&1" with those variables gives it: the console's input, output and error go to the round's files (Read-Host and
# Write-Host use them), the environment and the current folder are reset to this process's start values first, and the
# script runs in its own scope (&). A round that sets an empty value never comes here: .NET deletes such a variable.
param([string]$Requests, [string]$Replies)
# The console host keeps the first writer and reader it gets, so it gets these two for the whole process; each round
# points them at its own files.
class RoundWriter : System.IO.TextWriter {
  [System.IO.TextWriter]$Target
  [System.Text.Encoding] get_Encoding() { return $this.Target.Encoding }
  [void] Write([char]$c) { $this.Target.Write($c) }
  [void] Write([string]$s) { $this.Target.Write($s) }
  [void] Write([char[]]$b, [int]$i, [int]$n) { $this.Target.Write($b, $i, $n) }
  [void] WriteLine([string]$s) { $this.Target.WriteLine($s) }
  [void] WriteLine() { $this.Target.WriteLine() }
  [void] Flush() { $this.Target.Flush() }
}
class RoundReader : System.IO.TextReader {
  [System.IO.TextReader]$Source
  [string] ReadLine() { return $this.Source.ReadLine() }
  [int] Read() { return $this.Source.Read() }
  [int] Peek() { return $this.Source.Peek() }
  [int] Read([char[]]$b, [int]$i, [int]$n) { return $this.Source.Read($b, $i, $n) }
}
$rq = [System.IO.StreamReader]::new($Requests)
$rs = [System.IO.StreamWriter]::new($Replies); $rs.AutoFlush = $true
$cw = [RoundWriter]::new(); $cw.Target = [Console]::Out; $cr = [RoundReader]::new(); $cr.Source = [Console]::In
[Console]::SetOut($cw); [Console]::SetError($cw); [Console]::SetIn($cr)
$env0 = @{}; foreach ($e in [Environment]::GetEnvironmentVariables().GetEnumerator()) { $env0[[string]$e.Key] = [string]$e.Value }
$dir0 = (Get-Location).Path
while ($null -ne ($line = $rq.ReadLine())) {
  $f = $line -split "`t"
  foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) { if (-not $env0.ContainsKey([string]$k)) { [Environment]::SetEnvironmentVariable([string]$k, $null) } }
  foreach ($k in $env0.Keys) { [Environment]::SetEnvironmentVariable($k, $env0[$k]) }
  if ($f.Count -gt 3) { foreach ($kv in $f[3..($f.Count - 1)]) { $i = $kv.IndexOf('='); [Environment]::SetEnvironmentVariable($kv.Substring(0, $i), $kv.Substring($i + 1)) } }
  Set-Location -LiteralPath $dir0; [Environment]::CurrentDirectory = $dir0
  $w = [System.IO.StreamWriter]::new($f[2], $false, [System.Text.UTF8Encoding]::new($false)); $w.AutoFlush = $true
  $r = [System.IO.StreamReader]::new($f[1])
  $cw.Target = $w; $cr.Source = $r
  $global:LASTEXITCODE = 0; $rc = 0
  try { & $f[0]; if ($LASTEXITCODE) { $rc = $LASTEXITCODE } }
  catch { $w.WriteLine(($_ | Out-String)); $rc = 1 }
  finally { $cw.Target = [System.IO.TextWriter]::Null; $cr.Source = [System.IO.TextReader]::Null; $w.Dispose(); $r.Dispose() }
  $rs.WriteLine([string]$rc)
}
