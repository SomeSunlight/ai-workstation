#requires -Version 7.4
<#
.SYNOPSIS
  Install a new, separately pinned AI Workstation Linux on its own WSL distro.
.DESCRIPTION
  One operator command, reusing AIW's monitored SHA-256-pinned Ubuntu import
  and the official independent Linux project's installation contract.
  Existing WSL distributions are never reset, unregistered or adopted.
  -Action Shortcuts repairs only the Windows launcher, without WSL actions or
  rerunning Linux/NemoClaw installation.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Status', 'Verify', 'Shortcuts')][string]$Action = 'Install',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$DistroName = 'AIW-Nemo-New',
    [string]$InstallLocation = 'C:\WSL\AIW-Nemo-New',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')][string]$LinuxUser = 'moresunlight',
    [switch]$NoShortcuts,
    [switch]$SkipOnboarding,
    [switch]$NoAutomaticRestart
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'install-nemoclaw.ps1') `
    -Action $Action -DistroName $DistroName -InstallLocation $InstallLocation `
    -LinuxUser $LinuxUser -IndependentLinuxProject `
    -NoShortcuts:$NoShortcuts -SkipOnboarding:$SkipOnboarding `
    -NoAutomaticRestart:$NoAutomaticRestart
if (-not $?) { exit 1 }
