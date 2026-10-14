#requires -Version 7.4
# Executable Windows smoke test; no WSL distribution or Docker required.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$creator = Join-Path $root 'bootstrap/windows/Create-Shortcuts.ps1'
$installer = Join-Path $root 'bootstrap/windows/Install-AiWorkstation.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aiw-shortcuts-' + [Guid]::NewGuid().ToString('N'))
$shell = New-Object -ComObject WScript.Shell
$PSNativeCommandUseErrorActionPreference = $false

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
    $pwsh = Join-Path $PSHOME 'pwsh.exe'
    Assert-True ($link.TargetPath -ieq $pwsh) "Launcher does not use PowerShell: $path"
    $launcherPath = Join-Path $Launchers "$Name.ps1"
    $expected = ('-NoLogo -NoProfile -NoExit -File "{0}" -DistroName "{1}" -LinuxDirectory "{2}" -LauncherName "{3}"' -f `
        $launcherPath, $Distro, $LinuxPath, $Name)
    Assert-True ($link.Arguments -eq $expected) "Unexpected PowerShell launcher arguments: $path"
    Assert-True (Test-Path -LiteralPath $launcherPath -PathType Leaf) "Missing installed launcher script: $launcherPath"
    $body = Get-Content -LiteralPath $launcherPath -Raw
    Assert-True ($body.Contains('Manual start from PowerShell:')) "Missing launch diagnostics: $launcherPath"
    Assert-True ($body.Contains('--exec /bin/echo')) "Missing WSL startup probe: $launcherPath"
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

    # Real PowerShell process and installed per-icon PS1 script, with an isolated
    # mock executable. No actual WSL distribution is needed on the CI runner.
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
    Invoke-TestShortcuts -Distro Ubuntu-24.04 -Desktop $mockDesktop -Start $mockStart -Launchers $mockLaunchers

    $mockWorkstation = Join-Path $mockLaunchers 'Linux AI Workstation.ps1'
    $mockTerminal = Join-Path $mockLaunchers 'Linux Terminal.ps1'
    $pwshExecutable = Join-Path $PSHOME 'pwsh.exe'

    function Invoke-MockLauncher {
        param([string]$Path, [string]$Mode, [string]$Distro = 'Ubuntu-24.04',
              [string]$LinuxPath = '/home/moresunlight/ai-workstation',
              [string]$Label = 'Linux AI Workstation')
        $env:FAKE_WSL_MODE = $Mode
        $env:FAKE_WSL_TRACE = Join-Path $fixture 'wsl-calls.txt'
        $env:FAKE_WSL_MARKER = Join-Path $fixture 'first-attempt.txt'
        Remove-Item -LiteralPath $env:FAKE_WSL_TRACE, $env:FAKE_WSL_MARKER `
            -ErrorAction SilentlyContinue
        try {
            $output = (& $pwshExecutable -NoLogo -NoProfile -File $Path `
                -DistroName $Distro -LinuxDirectory $LinuxPath `
                -LauncherName $Label -WslExecutable $fakeWsl 2>&1 | Out-String)
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
        @{ File = $mockWorkstation; Path = '/home/moresunlight/ai-workstation'; Label = 'Linux AI Workstation' },
        @{ File = $mockTerminal; Path = '/home/moresunlight'; Label = 'Linux Terminal' }
    )) {
        $out = Invoke-MockLauncher -Path $entry.File -Mode 'ok' -LinuxPath $entry.Path -Label $entry.Label
        Assert-True ($out.Code -eq 0) "Launcher failed: $($entry.File). $($out.Output)"
        Assert-True ($out.Output.Contains('Manual start from PowerShell:')) 'Missing manual command hint'
        Assert-True ($out.Output.Contains('wsl -d Ubuntu-24.04')) 'Missing distro command hint'
        Assert-True ($out.Calls.Count -eq 2) 'Expected Linux probe followed by shell'
        Assert-True ($out.Calls[0] -match '--exec /bin/echo AIW_WSL_READY') 'Linux readiness probe missing'
        Assert-True ($out.Calls[1].Contains("--cd $($entry.Path)")) 'Shell did not use requested directory'
    }

    $retry = Invoke-MockLauncher -Path $mockWorkstation -Mode 'first-fail'
    Assert-True ($retry.Code -eq 0 -and $retry.Calls.Count -eq 3) 'Transient WSL failure did not retry once'

    $falseSuccess = Invoke-MockLauncher -Path $mockWorkstation -Mode 'false-success'
    Assert-True ($falseSuccess.Code -ne 0) 'Native return code 0 with WSL error must fail'
    Assert-True ($falseSuccess.Calls.Count -eq 2) 'False success should be retried once'
    Assert-True (-not $falseSuccess.Output.Contains('[OK] Linux command')) 'False success reported'
    Assert-True ($falseSuccess.Output.Contains('WSL_E_DISTRO_NOT_FOUND')) 'Lost original WSL error'

    $missing = Invoke-MockLauncher -Path $mockTerminal -Mode 'missing'
    Assert-True ($missing.Code -ne 0) 'Missing distribution incorrectly accepted'
    Assert-True ($missing.Output.Contains('Registered distributions')) 'No distribution diagnostics'

    $shellFailure = Invoke-MockLauncher -Path $mockWorkstation -Mode 'shell-fail'
    Assert-True ($shellFailure.Code -ne 0) 'Shell launch error was ignored'
    Assert-True ($shellFailure.Output.Contains('[ERROR] WSL started but')) 'Shell failure not distinguished'

    # A custom distro must use its own link/script and must not rewrite the
    # default distro launchers.
    Invoke-TestShortcuts -Distro Ubuntu-24.04-Test -Desktop $mockDesktop -Start $mockStart -Launchers $mockLaunchers
    $custom = Invoke-MockLauncher `
        -Path (Join-Path $mockLaunchers 'Linux Terminal (Ubuntu-24.04-Test).ps1') `
        -Mode 'ok' -Distro 'Ubuntu-24.04-Test' -LinuxPath '/home/moresunlight' `
        -Label 'Linux Terminal (Ubuntu-24.04-Test)'
    Assert-True ($custom.Code -eq 0) 'Custom distro PowerShell launcher failed'
    Assert-True ($custom.Calls[0].Contains('--distribution Ubuntu-24.04-Test')) 'Custom distro did not reach WSL'
    Assert-True ($custom.Output.Contains('wsl -d Ubuntu-24.04-Test')) 'Custom distro manual command missing'

    Write-Host 'Windows PowerShell shortcut launch, legacy migration, retry and failure tests passed.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
