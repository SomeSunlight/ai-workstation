#requires -Version 7.4
<#
.SYNOPSIS
    Creates Windows Desktop and Start Menu shortcuts for an AI Workstation WSL checkout.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName = 'Ubuntu-24.04',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser = 'moresunlight',
    [string]$ShortcutName = 'AI Workstation'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$displayName = if ($DistroName -eq 'Ubuntu-24.04') { $ShortcutName } else { "$ShortcutName ($DistroName)" }
$linuxPath = "/home/$LinuxUser/ai-workstation"
$wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$shell = New-Object -ComObject WScript.Shell

foreach ($folder in @($desktop, $startMenu)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $path = Join-Path $folder "$displayName.lnk"
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = $wslExe
    $shortcut.Arguments = ('--distribution "{0}" --cd "{1}"' -f $DistroName, $linuxPath)
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = "$wslExe,0"
    $shortcut.Description = "Open $displayName in WSL at $linuxPath"
    $shortcut.Save()
    Write-Host "Created $path"
}
