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

    Write-Host 'Windows shortcut creation, migration, idempotency and ownership tests passed.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
