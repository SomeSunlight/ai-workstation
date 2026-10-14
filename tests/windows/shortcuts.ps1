#requires -Version 7.4
# Executable Windows smoke test; no WSL distribution or Docker required.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$creator = Join-Path $root 'bootstrap/windows/Create-Shortcuts.ps1'
$installer = Join-Path $root 'bootstrap/windows/Install-AiWorkstation.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aiw-shortcuts-' + [Guid]::NewGuid().ToString('N'))
$shell = New-Object -ComObject WScript.Shell

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-LegacyLink {
    param(
        [string]$Folder, [string]$Name, [string]$LinuxPath,
        [string]$Launchers, [switch]$NotOwned
    )
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $link = $shell.CreateShortcut((Join-Path $Folder "$Name.lnk"))
    $link.TargetPath = Join-Path $env:WINDIR 'System32/cmd.exe'
    $launcher = Join-Path $Launchers "$Name.cmd"
    $link.Arguments = '/k "{0}"' -f $launcher
    $link.Description = "Open $Name in WSL at $LinuxPath"
    if ($NotOwned) {
        $link.Description = 'Personal user shortcut; do not touch'
    }
    $link.Save()
}

function Invoke-TestShortcuts {
    param([string]$Distro, [string]$Desktop, [string]$Start, [string]$Launchers)
    & $creator -DistroName $Distro -LinuxUser moresunlight `
        -DesktopDirectory $Desktop -StartMenuDirectory $Start -LauncherDirectory $Launchers
}

function Assert-Link {
    param([string]$Folder, [string]$Name, [string]$LinuxPath, [string]$Launchers, [string]$Distro)
    $path = Join-Path $Folder "$Name.lnk"
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Missing shortcut: $path"
    $link = $shell.CreateShortcut($path)
    Assert-True ($link.TargetPath -ieq (Join-Path $env:WINDIR 'System32/cmd.exe')) "Unexpected target: $path"
    $cmdPath = Join-Path $Launchers "$Name.cmd"
    Assert-True ($link.Arguments -eq ('/k "{0}"' -f $cmdPath)) "Incorrect launcher: $path"
    $body = Get-Content -LiteralPath $cmdPath -Raw
    Assert-True ($body.Contains("--distribution `"$Distro`" --cd `"$LinuxPath`"")) "Incorrect WSL target: $cmdPath"
}

try {
    $desktop = Join-Path $fixture 'default/Desktop'
    $start = Join-Path $fixture 'default/Start'
    $launchers = Join-Path $fixture 'default/Launchers'
    foreach ($folder in @($desktop, $start)) {
        New-LegacyLink -Folder $folder -Name 'AI Workstation' `
            -LinuxPath '/home/moresunlight/ai-workstation' -Launchers $launchers
        New-LegacyLink -Folder $folder -Name 'AI Workstation Terminal' `
            -LinuxPath '/home/moresunlight' -Launchers $launchers
        # An unrelated shortcut in the same folder must always remain.
        New-LegacyLink -Folder $folder -Name 'Other Linux Tools' `
            -LinuxPath '/home/other' -Launchers $launchers
    }

    Invoke-TestShortcuts -Distro Ubuntu-24.04 -Desktop $desktop -Start $start -Launchers $launchers
    foreach ($folder in @($desktop, $start)) {
        Assert-Link -Folder $folder -Name 'Linux AI Workstation' -Distro Ubuntu-24.04 `
            -LinuxPath '/home/moresunlight/ai-workstation' -Launchers $launchers
        Assert-Link -Folder $folder -Name 'Linux Terminal' -Distro Ubuntu-24.04 `
            -LinuxPath '/home/moresunlight' -Launchers $launchers
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $folder 'AI Workstation.lnk'))) 'Old AI Workstation link survived'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $folder 'AI Workstation Terminal.lnk'))) 'Old Terminal link survived'
        Assert-True (Test-Path -LiteralPath (Join-Path $folder 'Other Linux Tools.lnk')) 'Unrelated shortcut was removed'
    }

    # Deliberately user-modified legacy name: never delete by filename alone.
    New-LegacyLink -Folder $desktop -Name 'AI Workstation' `
        -LinuxPath '/home/moresunlight/ai-workstation' -Launchers $launchers -NotOwned
    Invoke-TestShortcuts -Distro Ubuntu-24.04 -Desktop $desktop -Start $start -Launchers $launchers
    Assert-True (Test-Path -LiteralPath (Join-Path $desktop 'AI Workstation.lnk')) 'Customized shortcut was deleted'
    Assert-True ((@(Get-ChildItem -LiteralPath $desktop -Filter '*.lnk')).Count -eq 4) 'Re-run created duplicate shortcuts'
    Assert-True ((@(Get-ChildItem -LiteralPath $start -Filter '*.lnk')).Count -eq 3) 'Re-run created duplicate Start Menu links'

    # Additional WSL distro names must not collide with default-distribution links.
    $testDesktop = Join-Path $fixture 'test/Desktop'
    $testStart = Join-Path $fixture 'test/Start'
    $testLaunchers = Join-Path $fixture 'test/Launchers'
    $oldA = 'AI Workstation (Ubuntu-24.04-Test)'
    $oldB = 'AI Workstation (Ubuntu-24.04-Test) Terminal'
    foreach ($folder in @($testDesktop, $testStart)) {
        New-LegacyLink -Folder $folder -Name $oldA -LinuxPath '/home/moresunlight/ai-workstation' -Launchers $testLaunchers
        New-LegacyLink -Folder $folder -Name $oldB -LinuxPath '/home/moresunlight' -Launchers $testLaunchers
    }
    Invoke-TestShortcuts -Distro Ubuntu-24.04-Test -Desktop $testDesktop -Start $testStart -Launchers $testLaunchers
    foreach ($folder in @($testDesktop, $testStart)) {
        Assert-Link -Folder $folder -Name 'Linux AI Workstation (Ubuntu-24.04-Test)' `
            -Distro Ubuntu-24.04-Test -LinuxPath '/home/moresunlight/ai-workstation' -Launchers $testLaunchers
        Assert-Link -Folder $folder -Name 'Linux Terminal (Ubuntu-24.04-Test)' `
            -Distro Ubuntu-24.04-Test -LinuxPath '/home/moresunlight' -Launchers $testLaunchers
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $folder "$oldA.lnk"))) 'Old test-distro link survived'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $folder "$oldB.lnk"))) 'Old test-distro terminal survived'
        Assert-True ((@(Get-ChildItem -LiteralPath $folder -Filter '*.lnk')).Count -eq 2) 'Test distro created duplicate links'
    }

    # The public installer must delegate shortcut creation, not maintain a duplicate implementation.
    $installerText = Get-Content -LiteralPath $installer -Raw
    Assert-True ($installerText.Contains("Join-Path `$PSScriptRoot 'Create-Shortcuts.ps1'")) 'Installer does not delegate to shortcut creator'
    Assert-True ($installerText.Contains("'Linux AI Workstation'")) 'Installer default shortcut name outdated'
    $publicEntry = Get-Content -LiteralPath (Join-Path $root 'install.ps1') -Raw
    Assert-True ($publicEntry.Contains("'Linux AI Workstation'")) 'Public install.ps1 default name outdated'

    # Exercise the generated cmd launchers without requiring an installed WSL
    # distribution on the Windows CI runner. Call the fake batch file as a real
    # child command to cover cmd.exe control flow, exit codes and retry behavior.
    $fakeWsl = Join-Path $fixture 'fake-wsl.cmd'
    Set-Content -LiteralPath $fakeWsl -Encoding ASCII -Value @'
@echo off
if /I "%~1"=="--list" (
  echo NAME STATE VERSION
  echo Ubuntu-24.04 Stopped 2
  exit /b 0
)
if defined FAKE_WSL_TRACE >>"%FAKE_WSL_TRACE%" echo %*
if /I "%FAKE_WSL_MODE%"=="missing" exit /b 3
if /I "%FAKE_WSL_MODE%"=="false-success" (
  echo Wsl/Service/WSL_E_DISTRO_NOT_FOUND 1>&2
  exit /b 0
)
if /I "%FAKE_WSL_MODE%"=="first-fail" if not exist "%FAKE_WSL_MARKER%" (
  >"%FAKE_WSL_MARKER%" echo first-failed
  exit /b 7
)
if /I "%FAKE_WSL_MODE%"=="shell-fail" if /I "%~3"=="--cd" exit /b 5
if /I "%~3"=="--exec" echo AIW_WSL_READY
exit /b 0
'@

    $mockDesktop = Join-Path $fixture 'mock/Desktop'
    $mockStart = Join-Path $fixture 'mock/Start'
    $mockLaunchers = Join-Path $fixture 'mock/Launchers'
    & $creator -DistroName Ubuntu-24.04 -LinuxUser moresunlight `
        -DesktopDirectory $mockDesktop -StartMenuDirectory $mockStart `
        -LauncherDirectory $mockLaunchers -WslExecutable $fakeWsl
    $mockWorkstation = Join-Path $mockLaunchers 'Linux AI Workstation.cmd'
    $mockTerminal = Join-Path $mockLaunchers 'Linux Terminal.cmd'

    function Invoke-MockLauncher {
        param([string]$Path, [string]$Mode)
        $env:FAKE_WSL_MODE = $Mode
        $env:FAKE_WSL_TRACE = Join-Path $fixture 'wsl-calls.txt'
        $env:FAKE_WSL_MARKER = Join-Path $fixture 'first-attempt.txt'
        Remove-Item -LiteralPath $env:FAKE_WSL_TRACE, $env:FAKE_WSL_MARKER `
            -ErrorAction SilentlyContinue
        try {
            $output = (& $Path 2>&1 | Out-String)
            $code = $LASTEXITCODE
            $calls = if (Test-Path -LiteralPath $env:FAKE_WSL_TRACE) {
                @(Get-Content -LiteralPath $env:FAKE_WSL_TRACE)
            }
            else { @() }
            return @{ Output = $output; Code = $code; Calls = $calls }
        }
        finally {
            Remove-Item Env:FAKE_WSL_MODE, Env:FAKE_WSL_TRACE, Env:FAKE_WSL_MARKER `
                -ErrorAction SilentlyContinue
        }
    }

    foreach ($entry in @(
        @{ File = $mockWorkstation; Path = '/home/moresunlight/ai-workstation' },
        @{ File = $mockTerminal; Path = '/home/moresunlight' }
    )) {
        $out = Invoke-MockLauncher -Path $entry.File -Mode 'ok'
        Assert-True ($out.Code -eq 0) "Launcher failed: $($entry.File)"
        Assert-True ($out.Output.Contains('Manual start from PowerShell:')) 'Missing always-visible command hint'
        Assert-True ($out.Output.Contains('wsl -d Ubuntu-24.04')) 'Missing manual distro command'
        Assert-True ($out.Calls.Count -eq 2) 'Expected WSL startup preflight followed by shell'
        Assert-True ($out.Calls[0] -match '--exec /bin/echo AIW_WSL_READY') 'Preflight did not run first'
        Assert-True ($out.Calls[1].Contains("--cd `"$($entry.Path)`"")) 'Shell was not opened at target path'
    }

    $retry = Invoke-MockLauncher -Path $mockWorkstation -Mode 'first-fail'
    Assert-True ($retry.Code -eq 0) 'Transient cold-start error did not recover'
    Assert-True ($retry.Calls.Count -eq 3) 'Transient error must retry once before shell'
    # Real owner regression: WSL printed DISTRO_NOT_FOUND and the previous
    # launcher falsely continued to [OK]. Even exit code 0 is not sufficient;
    # the marker can only come from an actually executed Linux command.
    $falseSuccess = Invoke-MockLauncher -Path $mockWorkstation -Mode 'false-success'
    Assert-True ($falseSuccess.Code -ne 0) 'WSL error with exit 0 was falsely accepted'
    Assert-True ($falseSuccess.Calls.Count -eq 2) 'WSL error should retry exactly once'
    Assert-True (-not $falseSuccess.Output.Contains('[OK] Linux command')) 'False WSL success was printed'
    Assert-True ($falseSuccess.Output.Contains('WSL_E_DISTRO_NOT_FOUND')) 'Lost WSL diagnostic'
    Assert-True ($falseSuccess.Output.Contains('no successful Linux execution marker')) 'Missing clear probe failure'

    $missing = Invoke-MockLauncher -Path $mockTerminal -Mode 'missing'
    Assert-True ($missing.Code -ne 0) 'Missing distribution must fail visibly'
    Assert-True ($missing.Output.Contains('Distributions registered for this Windows user:')) 'Missing distribution diagnostics'
    $shellFailure = Invoke-MockLauncher -Path $mockWorkstation -Mode 'shell-fail'
    Assert-True ($shellFailure.Code -ne 0) 'Shell failure must not masquerade as success'
    Assert-True ($shellFailure.Output.Contains('WSL started, but opening')) 'Missing separate shell error diagnostic'

    # Additional distro names survive all the way through startup and cd.
    & $creator -DistroName Ubuntu-24.04-Test -LinuxUser moresunlight `
        -DesktopDirectory $mockDesktop -StartMenuDirectory $mockStart `
        -LauncherDirectory $mockLaunchers -WslExecutable $fakeWsl
    $custom = Invoke-MockLauncher -Path (Join-Path $mockLaunchers 'Linux Terminal (Ubuntu-24.04-Test).cmd') -Mode 'ok'
    Assert-True ($custom.Code -eq 0) 'Custom distro launcher failed'
    Assert-True ($custom.Calls[0].Contains('--distribution "Ubuntu-24.04-Test"')) 'Custom distro lost in preflight'
    Assert-True ($custom.Output.Contains('wsl -d Ubuntu-24.04-Test')) 'Custom distro missing in manual hint'

    Write-Host 'Windows shortcut creation, migration, cold-start, retry, diagnostics and ownership tests passed.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
