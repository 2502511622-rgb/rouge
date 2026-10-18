param([Parameter(Mandatory=$true)][string]$Archive)
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:RUNNER_TEMP 'Switch 启动器 测试'
Expand-Archive -LiteralPath $Archive -DestinationPath $dest -Force
$root = Join-Path $dest 'SwitchLauncher'
$exe = Join-Path $root 'SwitchLauncher.exe'
$hashes = Get-Content -LiteralPath (Join-Path $root 'checksums.json') -Raw | ConvertFrom-Json
foreach ($entry in $hashes.PSObject.Properties) {
  if ((Get-FileHash -LiteralPath (Join-Path $root $entry.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value) { throw "Package hash mismatch: $($entry.Name)" }
}
$engineDir = Join-Path $dest '模拟器 & emulator'
New-Item -ItemType Directory -Path $engineDir -Force | Out-Null
$engine = Join-Path $engineDir 'Probe emulator.exe'
Copy-Item ./switch-launcher/tests/ProbeEmulator.exe -Destination $engine
$game = Join-Path $dest '游戏 & (test).xci'
[System.IO.File]::WriteAllText($game, 'Argument probe, not an actual game')
$env:SWITCH_LAUNCHER_PROBE_FILE = Join-Path $dest '收到的参数.txt'
function Run-Probe([string]$mode, [int]$expectedCode) {
  $arguments = "--probe `"$engine`" $mode `"$game`""
  $p = Start-Process -FilePath $exe -ArgumentList $arguments -Wait -PassThru
  if ($p.ExitCode -ne $expectedCode) { throw "Profile $mode returned $($p.ExitCode), expected $expectedCode" }
}
Run-Probe 'direct' 0
$lines = Get-Content -LiteralPath $env:SWITCH_LAUNCHER_PROBE_FILE -Encoding Unicode
if ($lines.Count -ne 3 -or $lines[0] -ne $engineDir -or $lines[1] -ne $engine -or $lines[2] -ne $game) { throw "Direct argv/CWD corrupted: $lines" }
Run-Probe 'dash-g' 0
$lines = Get-Content -LiteralPath $env:SWITCH_LAUNCHER_PROBE_FILE -Encoding Unicode
if ($lines.Count -ne 4 -or $lines[0] -ne $engineDir -or $lines[1] -ne $engine -or $lines[2] -ne '-g' -or $lines[3] -ne $game) { throw "-g argv/CWD corrupted: $lines" }
Run-Probe 'invalid' 12
$config = Join-Path $dest '配置检查'
$p = Start-Process -FilePath $exe -ArgumentList "--config-check `"$engine`" `"$game`" `"$config`"" -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Unicode config round-trip failed: $($p.ExitCode)" }
if (-not (Test-Path -LiteralPath (Join-Path $config 'config.ini'))) { throw 'Missing saved config' }
if (Test-Path -LiteralPath (Join-Path $config 'config.next.ini')) { throw 'Atomic config publication failed' }
$p = Start-Process -FilePath $exe -PassThru
try {
  $deadline = [DateTime]::UtcNow.AddSeconds(10)
  do { Start-Sleep -Milliseconds 250; $p.Refresh() } until ($p.HasExited -or $p.MainWindowHandle -ne 0 -or [DateTime]::UtcNow -gt $deadline)
  if ($p.HasExited -or $p.MainWindowHandle -eq 0) { throw 'Launcher UI did not create a window' }
  if (-not $p.CloseMainWindow()) { throw 'Could not close launcher normally' }
  if (-not $p.WaitForExit(10000)) { throw 'UI failed to close cleanly' }
  if ($p.ExitCode -ne 0) { throw "UI exit failed: $($p.ExitCode)" }
} finally { if (-not $p.HasExited) { $p.Kill() } }
Write-Host 'PASS: package hashes, direct and -g argv, Unicode/spaces/metacharacters, working directory, invalid-profile rejection, atomic Unicode config, real GUI startup and shutdown.'
Write-Host 'Real Switch emulator/game compatibility and gameplay are NOT covered by this probe.'
