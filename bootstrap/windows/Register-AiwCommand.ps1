#Requires -Version 7.4
<#
.SYNOPSIS
  Opt-in user-level registration of the native Windows 'aiw' command.
.DESCRIPTION
  Creates a small command shim under LOCALAPPDATA and adds only that private
  shim directory to the *user* PATH. Does not configure WSL, touch running
  services, edit PowerShell profiles or modify the machine PATH.
  Called from the repository-root aiw.cmd.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Remove', 'Status')]
    [string]$Action = 'Status'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$nativeEntrypoint = Join-Path $repository 'bootstrap\windows\Services.ps1'
$shimDirectory = Join-Path $env:LOCALAPPDATA 'AIWorkstation\bin'
$shimFile = Join-Path $shimDirectory 'aiw.cmd'
$marker = 'rem AIW-OWNED-NATIVE-COMMAND-SHIM-v1'
if (-not (Test-Path -LiteralPath $nativeEntrypoint -PathType Leaf)) {
    throw 'Native AI Workstation service entry point missing.'
}

function Read-UserPath {
    $value = [Environment]::GetEnvironmentVariable('Path', 'User')
    return $(if ($null -eq $value) { '' } else { [string]$value })
}
function UserPathContainsShim([string]$value) {
    foreach ($part in ($value -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($part)) {
            $expanded = [Environment]::ExpandEnvironmentVariables($part.Trim().Trim('"'))
            if ($expanded.TrimEnd('\') -ieq $shimDirectory.TrimEnd('\')) { return $true }
        }
    }
    return $false
}
function Read-OwnedShim {
    if (-not (Test-Path -LiteralPath $shimFile -PathType Leaf)) { return $false }
    $first = [IO.File]::ReadLines($shimFile) | Select-Object -First 1
    return ($first -ceq $marker)
}
function Assert-UnownedShimAbsent {
    if (Test-Path -LiteralPath $shimFile) {
        if (-not (Read-OwnedShim)) {
            throw 'An unrelated aiw.cmd already exists in the managed shim location. Refusing overwrite.'
        }
    }
}
function Make-ShimText {
    # The absolute checkout path is quoted and used only in a private shim.
    # Batch-special characters in the checkout path are explicitly unsupported.
    if ($nativeEntrypoint -match '[%!"\r\n]') {
        throw 'Checkout path contains characters unsupported in a Windows cmd shim; move the checkout.'
    }
    return @"
$marker
@echo off
pwsh.exe -NoProfile -File "$nativeEntrypoint" %*
exit /b %errorlevel%
"@
}
function Show-Status {
    $registration = UserPathContainsShim (Read-UserPath)
    Write-Host 'Native Windows AI Workstation command'
    Write-Host "Checkout:   $repository"
    Write-Host "Shim:       $shimFile"
    Write-Host ("Shim owned: " + (Read-OwnedShim))
    Write-Host "User PATH:  $registration"
    if ($registration -and (Read-OwnedShim)) {
        Write-Host "Use 'aiw' in a NEW PowerShell window, from any directory."
    }
    else {
        Write-Host "Inside this checkout, use '.\aiw'; use '.\aiw register' to enable the short command globally."
    }
}

switch ($Action) {
    'Status' {
        Show-Status
    }
    'Install' {
        Assert-UnownedShimAbsent
        $existing = Get-Command aiw -All -ErrorAction SilentlyContinue
        foreach ($item in @($existing)) {
            if ($item.Source -and $item.Source -ine $shimFile) {
                throw "A different 'aiw' command already exists on PATH: $($item.Source). Refusing to shadow it."
            }
        }
        New-Item -ItemType Directory -Path $shimDirectory -Force | Out-Null
        $body = Make-ShimText
        $staging = Join-Path $shimDirectory ('.aiw-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::WriteAllText($staging, ($body.TrimEnd([char]13, [char]10) + [Environment]::NewLine),
                [Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $staging -Destination $shimFile -Force
        }
        finally {
            if (Test-Path -LiteralPath $staging) {
                Remove-Item -LiteralPath $staging -Force
            }
        }
        $before = Read-UserPath
        if (-not (UserPathContainsShim $before)) {
            $updated = if ($before.TrimEnd(';')) {
                $before.TrimEnd(';') + ';' + $shimDirectory
            }
            else { $shimDirectory }
            [Environment]::SetEnvironmentVariable('Path', $updated, 'User')
        }
        Write-Host "[OK] Installed a native Windows 'aiw' command for this user."
        Write-Host 'Open a new PowerShell window, then run: aiw'
        Write-Host 'No administrator rights, WSL changes, or running-service changes.'
    }
    'Remove' {
        Assert-UnownedShimAbsent
        if (Test-Path -LiteralPath $shimFile) {
            Remove-Item -LiteralPath $shimFile -Force
        }
        # Remove only our exact shim directory from the user's PATH.
        $oldParts = @((Read-UserPath) -split ';')
        $newParts = @($oldParts | Where-Object {
            $candidate = [Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"'))
            $candidate.TrimEnd('\') -ine $shimDirectory.TrimEnd('\')
        })
        if ($newParts.Count -ne $oldParts.Count) {
            [Environment]::SetEnvironmentVariable('Path', ($newParts -join ';'), 'User')
        }
        Write-Host "[OK] Native Windows 'aiw' command unregistered for this user."
        Write-Host 'Open a new PowerShell window to refresh PATH. Existing services are untouched.'
    }
}
