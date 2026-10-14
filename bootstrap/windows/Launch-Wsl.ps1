#requires -Version 7.4
<#
.SYNOPSIS
    Opens an existing WSL distribution from the Windows penguin shortcuts.
.DESCRIPTION
    Runs under PowerShell (not cmd.exe). The owner reproduced a WSL
    distribution-not-found failure exclusively through a cmd.exe / call path,
    while the identical System32 wsl.exe command worked from PowerShell.
    This script is copied next to the installed Windows shortcuts, so it
    remains available even after deleting the installer checkout.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName,

    [Parameter(Mandatory)]
    [ValidatePattern('^/')]
    [string]$LinuxDirectory,

    [string]$LauncherName = 'Linux',

    # Explicitly injectable in tests; production uses the native System32 executable.
    [string]$WslExecutable = (Join-Path $env:WINDIR 'System32\wsl.exe')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

Write-Host "Starting $LauncherName"
Write-Host "WSL distribution: $DistroName"
Write-Host "Linux directory: $LinuxDirectory"
Write-Host ''
Write-Host 'Manual start from PowerShell:'
Write-Host "  wsl -d $DistroName"
Write-Host "  wsl -d $DistroName --cd $LinuxDirectory"
Write-Host ''

function Test-AiwWslReady {
    # An actual Linux process must return this exact stdout marker. Do not
    # announce success from a native exit code alone.
    $marker = 'AIW_WSL_READY'
    $outputLines = @()
    $code = -1

    try {
        $outputLines = @(& $WslExecutable --distribution $DistroName --exec /bin/echo $marker 2>&1)
        $code = $LASTEXITCODE
    }
    catch {
        Write-Host "[..] WSL launch failed: $($_.Exception.Message)"
        return $false
    }

    $sawMarker = $false
    foreach ($line in $outputLines) {
        if ([string]$line -ceq $marker) {
            $sawMarker = $true
        }
        elseif ($null -ne $line -and [string]$line -ne '') {
            Write-Host "[WSL] $line"
        }
    }

    if ($code -ne 0 -or -not $sawMarker) {
        Write-Host "[..] Linux readiness check failed (exit code: $code; marker found: $sawMarker)."
        return $false
    }

    return $true
}

Write-Host '[..] Starting or checking the WSL distribution...'
$ready = $false
for ($attempt = 1; $attempt -le 2; $attempt++) {
    if (Test-AiwWslReady) {
        $ready = $true
        break
    }

    if ($attempt -eq 1) {
        Write-Host '[..] WSL check failed. Retrying once...'
        Start-Sleep -Seconds 2
    }
}

if (-not $ready) {
    Write-Host '[ERROR] The installed WSL distribution could not be started.'
    Write-Host "Registered distributions for this Windows user:"
    & $WslExecutable --list --verbose
    Write-Host 'Inspect the original error above, then try the plain manual PowerShell command.'
    Write-Host 'Do not unregister or reinstall the distribution on this evidence.'
    throw "WSL did not execute a Linux command in '$DistroName'."
}

Write-Host '[OK] Linux command executed successfully. Opening the requested shell...'
& $WslExecutable --distribution $DistroName --cd $LinuxDirectory
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Write-Host "[ERROR] WSL started but the Linux shell or directory failed (exit code $exitCode)."
    Write-Host "Try: wsl -d $DistroName"
    throw "WSL shell exited with code $exitCode."
}

Write-Host ''
Write-Host 'Linux shell closed. This PowerShell window remains open for inspection.'
