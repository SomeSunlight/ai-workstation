#requires -Version 7.4
# Pure release parsing regression: never calls WSL, never unregisters anything.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'bootstrap/windows/NemoWslRelease.ps1')

function Assert-Release {
    param([string[]]$Lines, [string]$Expected)
    $actual = Get-AiwNemoUbuntuVersion -Lines $Lines
    if ($actual -cne $Expected) { throw "Expected Ubuntu $Expected, found $actual." }
}
function Assert-Rejected {
    param([string[]]$Lines)
    $rejected = $false
    try { $null = Get-AiwNemoUbuntuVersion -Lines $Lines } catch { $rejected = $true }
    if (-not $rejected) { throw 'Unexpected distro version was accepted for deletion.' }
}

Assert-Release -Lines @('NAME="Ubuntu"', 'ID=ubuntu', 'VERSION_ID="24.04"') -Expected '24.04'
Assert-Release -Lines @('ID=ubuntu', 'VERSION_ID="26.04"') -Expected '26.04'
Assert-Release -Lines @("ID=ubuntu`r", "VERSION_ID=`"26.04`"`r") -Expected '26.04'
Assert-Rejected -Lines @('ID=debian', 'VERSION_ID="26.04"')
Assert-Rejected -Lines @('ID=ubuntu', 'VERSION_ID="22.04"')
Assert-Rejected -Lines @('ID=ubuntu', 'VERSION_ID="27.04"')
Assert-Rejected -Lines @('ID=ubuntu')
$source = Get-Content (Join-Path $root 'bootstrap/windows/Remove-OldNemoWsl.ps1') -Raw
if (-not $source.Contains("Get-AiwNemoUbuntuVersion") -or
    -not $source.Contains("DELETE AIW-Nemo") -or
    -not $source.Contains("BasePath") -or
    -not $source.Contains("nemoclaw-podman") -or
    -not $source.Contains("--unregister")) {
    throw 'Guarded WSL cleanup source contract changed unexpectedly.'
}
Write-Host '[OK] Cleanup release parser accepts only known Ubuntu Nemo tests, including 26.04.'
