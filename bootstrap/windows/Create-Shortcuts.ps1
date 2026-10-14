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
    [string]$ShortcutName = 'Linux AI Workstation',
    # Test-only path overrides; normal installation uses the Windows user folders.
    [string]$DesktopDirectory = [Environment]::GetFolderPath('Desktop'),
    [string]$StartMenuDirectory = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [string]$LauncherDirectory = (Join-Path $env:LOCALAPPDATA 'AiWorkstationBootstrap\launchers'),
    # Test-only override for executable behavior checks without real WSL.
    [string]$WslExecutable = (Join-Path $env:WINDIR 'System32\wsl.exe')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$displayName = if ($DistroName -eq 'Ubuntu-24.04') { $ShortcutName } else { "$ShortcutName ($DistroName)" }
$terminalDisplayName = if ($DistroName -eq 'Ubuntu-24.04') { 'Linux Terminal' } else { "Linux Terminal ($DistroName)" }
$linuxPath = "/home/$LinuxUser/ai-workstation"
$linuxHome = "/home/$LinuxUser"
$wslExe = $WslExecutable
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
echo Manual start from PowerShell:
echo   wsl -d $DistroName
echo   wsl -d $DistroName --cd $LauncherLinuxPath
echo.
echo [..] Starting or checking the WSL distribution...
set "AIW_ATTEMPT=1"

:probe_wsl
rem Do not trust wsl.exe's exit status alone. A user observed WSL_E_DISTRO_NOT_FOUND
rem followed by [OK] with the old --exec /bin/true preflight.
rem A genuine Linux process must produce this exact marker on stdout.
set "AIW_PROBE=%TEMP%\aiw-wsl-%RANDOM%-%RANDOM%.txt"
call "$wslExe" --distribution "$DistroName" --exec /bin/echo AIW_WSL_READY >"%AIW_PROBE%"
set "AIW_EXIT=%ERRORLEVEL%"
findstr /x /c:"AIW_WSL_READY" "%AIW_PROBE%" >nul 2>&1
set "AIW_MARKER_EXIT=%ERRORLEVEL%"
if not "%AIW_MARKER_EXIT%"=="0" (
  echo [..] WSL produced no successful Linux execution marker. Output:
  type "%AIW_PROBE%"
)
del /q "%AIW_PROBE%" >nul 2>&1
if "%AIW_EXIT%"=="0" if "%AIW_MARKER_EXIT%"=="0" goto :wsl_ready
if "%AIW_ATTEMPT%"=="2" goto :wsl_start_failed
echo [..] First WSL start attempt failed. Retrying once...
set "AIW_ATTEMPT=2"
timeout /t 2 /nobreak >nul
goto :probe_wsl

:wsl_ready
echo [OK] Linux command executed successfully; opening the requested shell...
call "$wslExe" --distribution "$DistroName" --cd "$LauncherLinuxPath"
if errorlevel 1 goto :wsl_shell_failed
goto :done

:wsl_start_failed
set "AIW_FAILURE=1"
echo [ERROR] WSL could not start the requested distribution.
echo A stopped distribution normally starts automatically; no manual prestart is required.
goto :diagnostics

:wsl_shell_failed
set "AIW_FAILURE=1"
echo [ERROR] WSL started, but opening the requested Linux directory or shell failed.
echo Try the plain command above first, then inspect the requested Linux directory.
goto :diagnostics

:diagnostics
echo.
echo Distributions registered for this Windows user:
call "$wslExe" --list --verbose
echo.
echo If $DistroName is absent, check the Windows user or distribution registration.
echo If it is listed but cannot start, inspect the WSL error above.
echo For further diagnosis in PowerShell: wsl --status
echo To restart WSL manually if no other WSL jobs are running: wsl --shutdown
echo.

:done
echo.
echo This window stays open so WSL messages remain visible.
echo Type exit to close it.
if defined AIW_FAILURE exit /b 1
exit /b 0
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
    $shortcut.IconLocation = "$(Join-Path $env:WINDIR 'System32\wsl.exe'),0"
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
