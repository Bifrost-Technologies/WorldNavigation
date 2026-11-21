param()
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$packager = Join-Path $repo 'scripts/release.py'
if (Get-Command py -ErrorAction SilentlyContinue) { & py -3.11 $packager }
else { & python $packager }
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed; no upload performed.' }
Write-Output 'Install ZIP and checksum are in dist. This command does not push or upload.'
