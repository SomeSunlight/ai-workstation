#requires -Version 7.4
<#
.SYNOPSIS
    Install or verify one isolated NemoClaw + Hermes Ubuntu WSL distribution.
.DESCRIPTION
    Uses AIW's hash-pinned Ubuntu 26.04 image and idempotent Ansible setup
    for rootless Podman. The upstream NemoClaw wizard manages OpenShell,
    the Hermes sandbox and providers. Requires the WSL 2.9.13+ cgroup fix;
    never installs Docker Desktop or modifies other WSL distributions.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install','Status','Verify','Shortcuts')][string]$Action = 'Install',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$DistroName = 'AIW-Nemo',
    [string]$InstallLocation = 'C:\WSL\AIW-Nemo',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')][string]$LinuxUser = 'moresunlight',
    [string]$RepositoryRef = '',
    [switch]$NoShortcuts,
    [switch]$SkipLinuxInstall,
    [switch]$SkipOnboarding,
    [switch]$NoAutomaticRestart
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRef)) {
    $RepositoryRef = [string](& git -C $PSScriptRoot branch --show-current)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RepositoryRef)) {
        throw 'The installer needs a checked-out AIW branch (or an explicit -RepositoryRef).'
    }
}
if ($RepositoryRef -notmatch '^[A-Za-z0-9._/-]+$' -or $RepositoryRef.Contains('..')) {
    throw 'Invalid branch name; refusing to pass it to the WSL installer.'
}
$entry = Join-Path $PSScriptRoot 'bootstrap\windows\Install-AiWorkstation.ps1'
$params = @{
    Action = $Action
    Profile = 'NemoPodman'
    DistroName = $DistroName
    InstallLocation = $InstallLocation
    LinuxUser = $LinuxUser
    RepositoryRef = $RepositoryRef
    ShortcutName = 'NemoClaw Hermes'
    NoShortcuts = $NoShortcuts
    SkipLinuxInstall = $SkipLinuxInstall
    SkipOnboarding = $SkipOnboarding
    NoAutomaticRestart = $NoAutomaticRestart
}
& $entry @params
if (-not $?) { exit 1 }
