#requires -Version 7.4
<#
.SYNOPSIS
    Public Windows entry point for AI Workstation.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Status', 'Verify', 'Shortcuts')]
    [string]$Action = 'Install',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName = 'Ubuntu-24.04',
    [string]$InstallLocation = 'C:\WSL\Ubuntu-24.04',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser = 'moresunlight',
    [string]$RepositoryUrl = 'https://github.com/SomeSunlight/ai-workstation.git',
    [string]$RepositoryRef = 'main',
    [ValidatePattern('^\d+(MB|GB)$')]
    [string]$WslMemory = '48GB',
    [ValidatePattern('^\d+(MB|GB)$')]
    [string]$WslSwap = '8GB',
    [string]$ShortcutName = 'AI Workstation',
    [switch]$NoShortcuts,
    [switch]$NoAutomaticRestart,
    [switch]$SkipLinuxInstall,
    [switch]$ResumeAfterReboot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$implementation = Join-Path $PSScriptRoot 'bootstrap\windows\Install-AiWorkstation.ps1'
if (-not (Test-Path -LiteralPath $implementation -PathType Leaf)) {
    throw "Windows installer module not found: $implementation"
}

& $implementation @PSBoundParameters
exit 0
