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
    [ValidatePattern('^[^"]+$')]
    [string]$ShortcutName = 'Linux AI Workstation',
    # Test-only path overrides; normal installation uses the Windows user folders.
    [string]$DesktopDirectory = [Environment]::GetFolderPath('Desktop'),
    [string]$StartMenuDirectory = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [string]$LauncherDirectory = (Join-Path $env:LOCALAPPDATA 'AiWorkstationBootstrap\launchers')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$displayName = if ($DistroName -eq 'Ubuntu-24.04') { $ShortcutName } else { "$ShortcutName ($DistroName)" }
$terminalDisplayName = if ($DistroName -eq 'Ubuntu-24.04') { 'Linux Terminal' } else { "Linux Terminal ($DistroName)" }
$linuxPath = "/home/$LinuxUser/ai-workstation"
$linuxHome = "/home/$LinuxUser"
$wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$cmdExe = Join-Path $env:WINDIR 'System32\cmd.exe'
$desktop = $DesktopDirectory
$startMenu = $StartMenuDirectory
$launcherRoot = $LauncherDirectory
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
    param([Parameter(Mandatory)][string]$LauncherName)

    New-Item -ItemType Directory -Path $launcherRoot -Force | Out-Null
    $launcherPath = Join-Path $launcherRoot "$(ConvertTo-SafeFileName -Value $LauncherName).ps1"
    # Keep the Windows-side scripts working even after deleting the source checkout.
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-Wsl.ps1') `
        -Destination $launcherPath -Force
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
    $launcherPath = New-AiwLauncher -LauncherName $ShortcutDisplayName

    $shortcut = $shell.CreateShortcut($path)
    # The same System32 wsl.exe works under PowerShell on the owner's laptop
    # but fails from cmd.exe / call under the same Windows account.
    $shortcut.TargetPath = $pwshExe
    $shortcut.Arguments = ('-NoLogo -NoProfile -NoExit -File "{0}" -DistroName "{1}" -LinuxDirectory "{2}" -LauncherName "{3}"' -f `
        $launcherPath, $DistroName, $ShortcutLinuxPath, $ShortcutDisplayName)
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = "$wslExe,0"
    $shortcut.Description = "Open $ShortcutDisplayName in WSL at $ShortcutLinuxPath"
    $shortcut.Save()
    Write-Host "Created $path"
}


# Recognize only the exact links made by older AI Workstation installers.
# Do not delete an unrelated shortcut merely because it has the same name.
function Remove-LegacyAiwShortcut {
    param(
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$LegacyName,
        [Parameter(Mandatory)][string]$LegacyLinuxPath
    )

    $path = Join-Path $Folder "$LegacyName.lnk"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        $LegacyName -eq $displayName -or $LegacyName -eq $terminalDisplayName) {
        return
    }

    $originalLauncher = Join-Path $launcherRoot "$(ConvertTo-SafeFileName -Value $LegacyName).cmd"
    $expectedArguments = '/k "{0}"' -f $originalLauncher
    $expectedDescription = "Open $LegacyName in WSL at $LegacyLinuxPath"

    try {
        $existing = $shell.CreateShortcut($path)
        if ($existing.TargetPath -ieq $cmdExe -and
            $existing.Arguments -eq $expectedArguments -and
            $existing.Description -eq $expectedDescription) {
            Remove-Item -LiteralPath $path
            Write-Host "Removed obsolete AI Workstation shortcut $path"
        }
        else {
            Write-Host "Preserved non-owned or customized shortcut $path"
        }
    }
    catch {
        Write-Warning "Could not inspect legacy shortcut '$path'; leaving it unchanged: $_"
    }
}

# The old launchers are left untouched: they are harmless without .lnk links,
# and may still be used by a user-created shortcut.
$legacyDisplayName = if ($DistroName -eq 'Ubuntu-24.04') { 'AI Workstation' } else { "AI Workstation ($DistroName)" }
$legacyTerminalName = "$legacyDisplayName Terminal"

foreach ($folder in @($desktop, $startMenu)) {
    New-AiwShortcut `
        -Folder $folder `
        -ShortcutDisplayName $displayName `
        -ShortcutLinuxPath $linuxPath

    New-AiwShortcut `
        -Folder $folder `
        -ShortcutDisplayName $terminalDisplayName `
        -ShortcutLinuxPath $linuxHome

    # Create/refresh both replacements before removing old links.
    Remove-LegacyAiwShortcut -Folder $folder -LegacyName $legacyDisplayName -LegacyLinuxPath $linuxPath
    Remove-LegacyAiwShortcut -Folder $folder -LegacyName $legacyTerminalName -LegacyLinuxPath $linuxHome
}
