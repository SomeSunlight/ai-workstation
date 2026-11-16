#requires -Version 7.4
# Unit-only WSL version guard: no WSL starts, updates or host modifications.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'bootstrap/windows/NemoWslVersion.ps1')

function Assert-Version {
    param([string[]]$Lines, [string]$Expected)
    $got = Get-AiwNemoWslEngineVersion -VersionOutput $Lines
    if ($got.ToString() -cne $Expected) { throw "Expected $Expected, read $got" }
    Assert-AiwNemoWslEngineReady -InstalledVersion $got
}
function Assert-Blocked {
    param([string[]]$Lines)
    $version = Get-AiwNemoWslEngineVersion -VersionOutput $Lines
    $threw = $false
    try { Assert-AiwNemoWslEngineReady -InstalledVersion $version }
    catch { $threw = $true }
    if (-not $threw) { throw "Outdated WSL $version passed cgroup isolation guard" }
}

Assert-Version -Lines @("WSL version: 2.9.13.0", "WSLg version: 1.0.73") -Expected '2.9.13.0'
Assert-Version -Lines @("WSL-Version: 3.0.5.0", "Kernelversion: 6.18") -Expected '3.0.5.0'
Assert-Version -Lines @("WSL-Version: 3.0.5.0`r") -Expected '3.0.5.0'
Assert-Blocked -Lines @('WSL version: 2.7.14.0')
Assert-Blocked -Lines @('WSL-Version: 2.9.12.0')
$invalid = $false
try { $null = Get-AiwNemoWslEngineVersion -VersionOutput @('WSLg version: 9.9.9.0') }
catch { $invalid = $true }
if (-not $invalid) { throw 'WSLg version was accepted as the WSL engine version' }

$installer = Get-Content (Join-Path $root 'bootstrap/windows/Install-AiWorkstation.ps1') -Raw
if (-not $installer.Contains('Assert-AiwNemoWslEngineReady') -or
    -not $installer.Contains('Get-AiwNemoWslEngineVersion') -or
    -not $installer.Contains('Existing WSL version preserved; no global WSL update')) {
    throw 'WSL platform guard was removed or the implicit update policy changed.'
}
Write-Host '[OK] Nemo WSL platform requires released per-distro systemd cgroups; no global updates.'
