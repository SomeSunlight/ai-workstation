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
    Assert-True ($public.Contains("Profile = 'NemoClaw'")) 'Public profile is not selected'
    Assert-True ($public.Contains("DistroName = 'AIW-Nemo'")) 'Wrong default distro'
    Assert-True ($internal.Contains('Preserving global .wslconfig')) 'Shared WSL config is not guarded'
    Assert-True ($internal.Contains('Create-NemoClawShortcut.ps1')) 'New shortcut not routed'
    Assert-True ($internal.Contains('install --yes --profile nemoclaw')) 'Nemo Linux profile not routed'
    Assert-True ($internal.Contains('not marked as the NemoClaw profile')) 'Unrelated existing distro not protected'

    # A preexisting, manually customized shortcut must be rejected.
    $alien = $shell.CreateShortcut((Join-Path $start "$label.lnk"))
    $alien.TargetPath = Join-Path $env:WINDIR 'System32\wsl.exe'
    $alien.Description = 'Unrelated personal link'
    $alien.Save()
    $refused = $false
    try { & $creator @arguments }
    catch { $refused = $true }
    Assert-True $refused 'Unowned shortcut was overwritten'
    Write-Host '[OK] NemoClaw one-penguin launcher idempotence and WSL profile contracts.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
