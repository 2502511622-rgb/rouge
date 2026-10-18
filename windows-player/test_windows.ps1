param([Parameter(Mandatory=$true)][string]$Archive)
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:RUNNER_TEMP 'Shining Soul 中文路径'
Expand-Archive -LiteralPath $Archive -DestinationPath $dest -Force
$root = Join-Path $dest 'ShiningSoul-Windows'
$exe = Join-Path $root 'ShiningSoul.exe'
$checksums = Get-Content -LiteralPath (Join-Path $root 'checksums.json') -Raw | ConvertFrom-Json
foreach ($property in $checksums.PSObject.Properties) {
  $file = Join-Path $root $property.Name
  $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($hash -ne $property.Value) { throw "Package hash mismatch: $($property.Name)" }
}
$p = Start-Process -FilePath $exe -ArgumentList '--self-test' -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { throw "Windows engine self-test failed: $($p.ExitCode)" }
$probe = Join-Path $dest '哈希 test.txt'
[System.IO.File]::WriteAllBytes($probe, [System.Text.Encoding]::UTF8.GetBytes("Windows launcher test`n"))
$out = Join-Path $dest 'hash.txt'
$p = Start-Process -FilePath $exe -ArgumentList "--hash-file `"$probe`"" -Wait -PassThru -RedirectStandardOutput $out
if ($p.ExitCode -ne 0) { throw "BCrypt hash failed: $($p.ExitCode)" }
$expected = (Get-FileHash -LiteralPath $probe -Algorithm SHA256).Hash.ToLowerInvariant()
$observed = (Get-Content -LiteralPath $out -Raw).Trim()
if ($observed -ne $expected) { throw "BCrypt SHA-256 mismatch: $observed" }
$p = Start-Process -FilePath $exe -ArgumentList "--validate-rom `"$probe`"" -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 4) { throw "Invalid ROM was not rejected: $($p.ExitCode)" }
Write-Host 'PASS: package hashes, Unicode paths, launcher PE runtime, official Windows engine startup, BCrypt SHA-256, invalid-ROM rejection.'
Write-Host 'Game ROM import, interactive gameplay, audio, saves and completion are NOT covered by this CI test.'
