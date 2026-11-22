#requires -Version 7.4
# A single NemoClaw penguin per explicit WSL distro. Never touch legacy links.
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$DistroName = 'AIW-Nemo',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')][string]$LinuxUser = 'moresunlight',
    [switch]$IndependentLinuxProject,
    [string]$DesktopDirectory = [Environment]::GetFolderPath('Desktop'),
    [string]$StartMenuDirectory = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [string]$LauncherDirectory = (Join-Path $env:LOCALAPPDATA 'AiWorkstationBootstrap\launchers')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$display = "NemoClaw Hermes ($DistroName)"
$linuxWorkdir = 'ai-workstation'
if ($IndependentLinuxProject) {
    if ($DistroName -in @('Ubuntu-24.04', 'Ubuntu-26.04', 'AIW-Nemo')) {
        throw "Refusing independent Linux launcher for protected distro '$DistroName'."
    }
    # Manifest is the only authority for the independent checkout directory.
    $manifestPath = Join-Path $PSScriptRoot '../../config/linux-project.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or
        $manifest.project -cne 'ai-workstation-linux' -or
        $manifest.contract -cne 'linux-native-install-status-verify-v1' -or
        $manifest.repository -cne 'https://github.com/SomeSunlight/ai-workstation-linux.git' -or
        [string]$manifest.workdir -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}
$wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$shell = New-Object -ComObject WScript.Shell

New-Item -ItemType Directory -Path $LauncherDirectory -Force | Out-Null
$launcher = Join-Path $LauncherDirectory ("NemoClaw-" + $DistroName + ".ps1")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-NemoClaw.ps1') -Destination $launcher -Force
$iconSource = Join-Path $PSScriptRoot 'nemoclaw-hermes.ico'
$iconPath = Join-Path $LauncherDirectory 'nemoclaw-hermes.ico'
if (Test-Path -LiteralPath $iconSource -PathType Leaf) {
    Copy-Item -LiteralPath $iconSource -Destination $iconPath -Force
}
$iconLocation = if (Test-Path -LiteralPath $iconPath -PathType Leaf) { "$iconPath,0" } else { "$wslExe,0" }
$expectedArgs = '-NoLogo -NoProfile -NoExit -File "{0}" -DistroName "{1}" -LinuxUser "{2}" -LinuxWorkdir "{3}"' -f $launcher, $DistroName, $LinuxUser, $linuxWorkdir
foreach ($directory in @($DesktopDirectory, $StartMenuDirectory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $shortcutPath = Join-Path $directory "$display.lnk"
    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        $existing = $shell.CreateShortcut($shortcutPath)
        if ($existing.Description -ne "AIW NemoClaw profile: $DistroName" -or
            $existing.TargetPath -ine $pwshExe) {
            throw "Refusing to overwrite an unrelated or customized shortcut: $shortcutPath"
        }
    }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $pwshExe
    $shortcut.Arguments = $expectedArgs
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = $iconLocation
    $shortcut.Description = "AIW NemoClaw profile: $DistroName"
    $shortcut.Save()
    Write-Host "Ready: $shortcutPath"
}
) {
        throw 'Invalid independent Linux project manifest; shortcut not created.'
    }
    $linuxWorkdir = [string]$manifest.workdir
}
$wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$shell = New-Object -ComObject WScript.Shell

New-Item -ItemType Directory -Path $LauncherDirectory -Force | Out-Null
$launcher = Join-Path $LauncherDirectory ("NemoClaw-" + $DistroName + ".ps1")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-NemoClaw.ps1') -Destination $launcher -Force
$iconSource = Join-Path $PSScriptRoot 'nemoclaw-hermes.ico'
$iconPath = Join-Path $LauncherDirectory 'nemoclaw-hermes.ico'
if (Test-Path -LiteralPath $iconSource -PathType Leaf) {
    Copy-Item -LiteralPath $iconSource -Destination $iconPath -Force
}
$iconLocation = if (Test-Path -LiteralPath $iconPath -PathType Leaf) { "$iconPath,0" } else { "$wslExe,0" }
$expectedArgs = '-NoLogo -NoProfile -NoExit -File "{0}" -DistroName "{1}" -LinuxUser "{2}"' -f $launcher, $DistroName, $LinuxUser
foreach ($directory in @($DesktopDirectory, $StartMenuDirectory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $shortcutPath = Join-Path $directory "$display.lnk"
    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        $existing = $shell.CreateShortcut($shortcutPath)
        if ($existing.Description -ne "AIW NemoClaw profile: $DistroName" -or
            $existing.TargetPath -ine $pwshExe) {
            throw "Refusing to overwrite an unrelated or customized shortcut: $shortcutPath"
        }
    }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $pwshExe
    $shortcut.Arguments = $expectedArgs
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = $iconLocation
    $shortcut.Description = "AIW NemoClaw profile: $DistroName"
    $shortcut.Save()
    Write-Host "Ready: $shortcutPath"
}
