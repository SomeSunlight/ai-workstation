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
$terminalDisplayName = "$displayName Terminal"
$linuxPath = "/home/$LinuxUser/ai-workstation"
$linuxHome = "/home/$LinuxUser"
$wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
$cmdExe = Join-Path $env:WINDIR 'System32\cmd.exe'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$launcherRoot = Join-Path $env:LOCALAPPDATA 'AiWorkstationBootstrap\launchers'
$shell = New-Object -ComObject WScript.Shell

function ConvertTo-SafeFileName {
    param([Parameter(Mandatory)][string]$Value)

    $safe = $Value
    foreach ($invalid in [IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$invalid, '_')
    }

    return $safe
}

function New-AiwLauncher {
    param(
        [Parameter(Mandatory)][string]$LauncherName,
        [Parameter(Mandatory)][string]$LauncherDisplayName,
        [Parameter(Mandatory)][string]$LauncherLinuxPath
    )

    New-Item -ItemType Directory -Path $launcherRoot -Force | Out-Null
    $launcherPath = Join-Path $launcherRoot "$(ConvertTo-SafeFileName -Value $LauncherName).cmd"
    $content = @"
@echo off
setlocal
echo Starting $LauncherDisplayName
echo WSL distribution: $DistroName
echo Linux directory: $LauncherLinuxPath
echo.
"$wslExe" --distribution "$DistroName" --cd "$LauncherLinuxPath"
set "AIW_EXIT=%ERRORLEVEL%"
if not "%AIW_EXIT%"=="0" (
  echo.
  echo WSL failed with exit code %AIW_EXIT%.
  echo.
  echo Try from PowerShell:
  echo   wsl --shutdown
  echo   wsl -d $DistroName
  echo.
)
echo.
echo This window stays open so WSL messages remain visible.
echo Type exit to close it.
"@

    Set-Content -LiteralPath $launcherPath -Value $content -Encoding ASCII
    return $launcherPath
}

function New-AiwShortcut {
    param(
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$ShortcutDisplayName,
        [Parameter(Mandatory)][string]$ShortcutLinuxPath
    )

    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $path = Join-Path $Folder "$ShortcutDisplayName.lnk"
    $launcherPath = New-AiwLauncher `
        -LauncherName $ShortcutDisplayName `
        -LauncherDisplayName $ShortcutDisplayName `
        -LauncherLinuxPath $ShortcutLinuxPath

    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = $cmdExe
    $shortcut.Arguments = ('/k "{0}"' -f $launcherPath)
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = "$wslExe,0"
    $shortcut.Description = "Open $ShortcutDisplayName in WSL at $ShortcutLinuxPath"
    $shortcut.Save()
    Write-Host "Created $path"
}

foreach ($folder in @($desktop, $startMenu)) {
    New-AiwShortcut `
        -Folder $folder `
        -ShortcutDisplayName $displayName `
        -ShortcutLinuxPath $linuxPath

    New-AiwShortcut `
        -Folder $folder `
        -ShortcutDisplayName $terminalDisplayName `
        -ShortcutLinuxPath $linuxHome
}
