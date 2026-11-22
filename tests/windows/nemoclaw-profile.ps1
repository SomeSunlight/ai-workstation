#requires -Version 7.4
# No real WSL, Docker, NemoClaw or host changes: isolated shortcut/contract tests.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aiw-nemoclaw-' + [guid]::NewGuid().ToString('N'))
$creator = Join-Path $root 'bootstrap/windows/Create-NemoClawShortcut.ps1'
$shell = New-Object -ComObject WScript.Shell
function Assert-True([bool]$value, [string]$label) {
    if (-not $value) { throw $label }
}
try {
    $desktop = Join-Path $fixture 'Desktop'
    $start = Join-Path $fixture 'Start'
    $launchers = Join-Path $fixture 'Launchers'
    New-Item -ItemType Directory -Path $desktop, $start -Force | Out-Null
    $legacy = Join-Path $desktop 'Linux AI Workstation.lnk'
    $l = $shell.CreateShortcut($legacy)
    $l.TargetPath = Join-Path $env:WINDIR 'System32\wsl.exe'
    $l.Description = 'Original AIW penguin'
    $l.Save()
    $arguments = @{
        DistroName = 'AIW-Nemo'
        LinuxUser = 'moresunlight'
        DesktopDirectory = $desktop
        StartMenuDirectory = $start
        LauncherDirectory = $launchers
    }
    1..2 | ForEach-Object {
        & $creator @arguments
        Assert-True ($?) 'Shortcut creator failed'
    }
    $label = 'NemoClaw Hermes (AIW-Nemo)'
    foreach ($folder in @($desktop, $start)) {
        $path = Join-Path $folder "$label.lnk"
        Assert-True (Test-Path -LiteralPath $path) "Missing NemoClaw shortcut: $path"
        $link = $shell.CreateShortcut($path)
        Assert-True ($link.Description -eq 'AIW NemoClaw profile: AIW-Nemo') 'Wrong shortcut ownership'
        Assert-True ($link.TargetPath -ieq (Join-Path $PSHOME 'pwsh.exe')) 'Not PowerShell launcher'
        Assert-True ($link.Arguments.Contains('Launchers\NemoClaw-AIW-Nemo.ps1')) 'Wrong launcher'
        Assert-True ($link.Arguments.Contains('-DistroName "AIW-Nemo"')) 'Wrong WSL target'
        Assert-True ($link.IconLocation.Contains('nemoclaw-hermes.ico')) 'Missing own mascot icon'
        $expected = if ($folder -eq $desktop) { 2 } else { 1 }
        Assert-True ((@(Get-ChildItem $folder -Filter '*.lnk')).Count -eq $expected) 'Duplicate/unrelated shortcut created'
    }
    Assert-True (Test-Path $legacy) 'Legacy shortcut was touched'
    Assert-True (Test-Path (Join-Path $launchers 'nemoclaw-hermes.ico')) 'Mascot binary was not installed'
    $installed = $shell.CreateShortcut($legacy)
    Assert-True ($installed.Description -eq 'Original AIW penguin') 'Legacy shortcut changed'

    $public = Get-Content (Join-Path $root 'install-nemoclaw.ps1') -Raw
    $internal = Get-Content (Join-Path $root 'bootstrap/windows/Install-AiWorkstation.ps1') -Raw
    Assert-True ($public.Contains("Profile = 'NemoPodman'")) 'Public profile is not selected'
    Assert-True ($public.Contains("DistroName = 'AIW-Nemo'")) 'Wrong default distro'
    Assert-True ($internal.Contains('Preserving global .wslconfig')) 'Shared WSL config is not guarded'
    Assert-True ($internal.Contains('Create-NemoClawShortcut.ps1')) 'New shortcut not routed'
    Assert-True ($internal.Contains('install --yes --profile nemoclaw-podman')) 'Nemo Linux profile not routed'
    Assert-True ($internal.Contains('not marked as the NemoClaw profile')) 'Unrelated existing distro not protected'

    $markerCheck = Get-Content (Join-Path $root 'bootstrap/windows/Launch-NemoClaw.ps1') -Raw
    Assert-True ($markerCheck.Contains('nemoclaw-podman')) 'Launcher does not validate the Podman WSL profile'
    $cleanup = Get-Content (Join-Path $root 'bootstrap/windows/Remove-OldNemoWsl.ps1') -Raw
    Assert-True ($cleanup.Contains('DELETE AIW-Nemo')) 'Dangerous old distribution cleanup is not confirmed'
    $releaseHelper = Get-Content (Join-Path $root 'bootstrap/windows/NemoWslRelease.ps1') -Raw
    Assert-True ($cleanup.Contains('Get-AiwNemoUbuntuVersion')) 'Cleanup does not check Ubuntu identity'
    Assert-True ($releaseHelper.Contains('VERSION_ID')) 'Cleanup is not constrained to Ubuntu release'
    Assert-True ((Get-Content (Join-Path $root 'config/versions.json') -Raw).Contains('ubuntu-26.04.1-wsl-amd64.wsl')) 'New WSL image pin missing'

    # A preexisting, manually customized shortcut must be rejected.
    $alien = $shell.CreateShortcut((Join-Path $start "$label.lnk"))
    $alien.TargetPath = Join-Path $env:WINDIR 'System32\wsl.exe'
    $alien.Description = 'Unrelated personal link'
    $alien.Save()
    $refused = $false
    try { & $creator @arguments }
    catch { $refused = $true }
    Assert-True $refused 'Unowned shortcut was overwritten'
    # Independent AIW Linux must use a separate checkout path while the
    # existing AIW-Nemo link and any unrelated shortcut remain untouched.
    $standalone = $arguments.Clone()
    $standalone['DistroName'] = 'AIW-Nemo-New'
    $standalone['IndependentLinuxProject'] = $true
    1..2 | ForEach-Object {
        & $creator @standalone
        Assert-True ($?) 'Independent project shortcut generation failed'
    }
    foreach ($folder in @($desktop, $start)) {
        $shortcutPath = Join-Path $folder 'NemoClaw Hermes (AIW-Nemo-New).lnk'
        Assert-True (Test-Path -LiteralPath $shortcutPath) 'New NemoClaw shortcut missing'
        $newLink = $shell.CreateShortcut($shortcutPath)
        Assert-True ($newLink.Arguments.Contains('-DistroName "AIW-Nemo-New"')) 'New penguin targets wrong distro'
        Assert-True ($newLink.Arguments.Contains('-LinuxWorkdir "ai-workstation-linux"')) 'New penguin uses stale legacy Linux checkout'
        Assert-True ($newLink.Description -eq 'AIW NemoClaw profile: AIW-Nemo-New') 'New penguin ownership changed'
    }
    $oldLink = $shell.CreateShortcut((Join-Path $desktop 'NemoClaw Hermes (AIW-Nemo).lnk'))
    Assert-True (-not $oldLink.Arguments.Contains('-LinuxWorkdir "ai-workstation-linux"')) 'Legacy penguin was silently repointed'
    Assert-True (Test-Path $legacy) 'Unrelated legacy penguin removed by independent shortcut'

    # Actually execute the copied launcher with a Windows fake wsl.exe:
    # it must invoke exactly the independent checkout, not ~/ai-workstation.
    $fakeWsl = Join-Path $fixture 'fake-wsl.cmd'
    Set-Content -LiteralPath $fakeWsl -Encoding Ascii -Value @'
@echo off
if defined FAKE_NEMO_WSL_TRACE >>"%FAKE_NEMO_WSL_TRACE%" echo %*
if /I "%~4"=="root" echo nemoclaw-podman
exit /b 0
'@
    $tracePath = Join-Path $fixture 'wsl-launch-args.txt'
    $env:FAKE_NEMO_WSL_TRACE = $tracePath
    try {
        & (Join-Path $launchers 'NemoClaw-AIW-Nemo-New.ps1') -DistroName AIW-Nemo-New `
            -LinuxUser moresunlight -LinuxWorkdir ai-workstation-linux -WslExecutable $fakeWsl
        Assert-True ($?) 'New standalone launcher failed with mock WSL'
        $calls = @(Get-Content -LiteralPath $tracePath)
        Assert-True ($calls.Count -eq 2) 'Expected marker probe and exactly one Linux launcher call'
        Assert-True ($calls[1].Contains('--cd /home/moresunlight/ai-workstation-linux')) 'Standalone Linux menu launched from old directory'
        Assert-True ($calls[1].Contains('--exec /bin/bash')) 'Linux menu not invoked by bash'
        Clear-Content -LiteralPath $tracePath
        & (Join-Path $launchers 'NemoClaw-AIW-Nemo.ps1') -DistroName AIW-Nemo `
            -LinuxUser moresunlight -WslExecutable $fakeWsl
        Assert-True ($?) 'Legacy launcher failed with mock WSL'
        $oldCalls = @(Get-Content -LiteralPath $tracePath)
        Assert-True ($oldCalls.Count -eq 2) 'Legacy launcher should make only marker probe and menu call'
        Assert-True ($oldCalls[1].Contains('--cd /home/moresunlight/ai-workstation ')) 'Legacy Linux menu path was changed'
    }
    finally {
        Remove-Item Env:FAKE_NEMO_WSL_TRACE -ErrorAction SilentlyContinue
    }
    $entry = Get-Content -LiteralPath (Join-Path $root 'install-linux-workstation.ps1') -Raw
    Assert-True ($entry.Contains("'Install', 'Status', 'Verify', 'Shortcuts'")) 'Public standalone entrypoint cannot repair shortcuts without reinstall'
    Assert-True ($internal.Contains('-IndependentLinuxProject:$IndependentLinuxProject')) 'Installer failed to forward independent workdir to penguin creator'
    Write-Host '[OK] Standalone penguin: correct pinned workdir, real launcher invocation, legacy isolation.'

    Write-Host '[OK] NemoClaw one-penguin launcher idempotence and WSL profile contracts.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
