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
    $homeLabel = 'NemoClaw Linux Home (AIW-Nemo)'
    foreach ($folder in @($desktop, $start)) {
        foreach ($entry in @(
            @{ Name = $label; Mode = 'Workbench'; Owner = 'AIW NemoClaw profile: AIW-Nemo' },
            @{ Name = $homeLabel; Mode = 'Home'; Owner = 'AIW NemoClaw home profile: AIW-Nemo' }
        )) {
            $path = Join-Path $folder "$($entry.Name).lnk"
            Assert-True (Test-Path -LiteralPath $path) "Missing NemoClaw shortcut: $path"
            $link = $shell.CreateShortcut($path)
            Assert-True ($link.Description -eq $entry.Owner) 'Wrong shortcut ownership'
            Assert-True ($link.TargetPath -ieq (Join-Path $PSHOME 'pwsh.exe')) 'Not PowerShell launcher'
            Assert-True ($link.Arguments.Contains('Launchers\NemoClaw-AIW-Nemo.ps1')) 'Wrong launcher'
            Assert-True ($link.Arguments.Contains('-DistroName "AIW-Nemo"')) 'Wrong WSL target'
            Assert-True ($link.Arguments.Contains("-Mode `"$($entry.Mode)`"")) 'Wrong Linux shell mode'
            Assert-True (-not $link.Arguments.Contains('-NoExit')) 'Shortcut must not expose a PowerShell shell'
            Assert-True ($link.IconLocation.Contains('nemoclaw-hermes.ico')) 'Missing own mascot icon'
        }
        $expected = if ($folder -eq $desktop) { 3 } else { 2 }
        Assert-True ((@(Get-ChildItem $folder -Filter '*.lnk')).Count -eq $expected) 'Duplicate/unrelated shortcut created'
    }
    Assert-True (Test-Path $legacy) 'Legacy shortcut was touched'
    Assert-True (Test-Path (Join-Path $launchers 'nemoclaw-hermes.ico')) 'Mascot binary was not installed'
    # A file existing on disk is not enough: Windows must decode the icon.
    $mascot = [System.Drawing.Icon]::new((Join-Path $launchers 'nemoclaw-hermes.ico'))
    try {
        Assert-True ($mascot.Width -eq 64 -and $mascot.Height -eq 64) 'Invalid Windows penguin ICO'
    }
    finally { $mascot.Dispose() }

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

    # Shortcut-only repair must work even on a detached checkout and must not
    # invoke Git branch discovery or the Linux installer.
    $shortcutEntry = Get-Content (Join-Path $root 'install-nemoclaw.ps1') -Raw
    Assert-True ($shortcutEntry.Contains('if ($Action -eq ''Shortcuts'')')) 'Shortcut-only branch bypass missing'
    Assert-True ($shortcutEntry.Contains('$RepositoryRef = ''main''')) 'Shortcut repair should not need a current Git branch'

    $markerCheck = Get-Content (Join-Path $root 'bootstrap/windows/Launch-NemoClaw.ps1') -Raw
    Assert-True ($markerCheck.Contains('nemoclaw-podman')) 'Launcher does not validate the Podman WSL profile'
    Assert-True ($markerCheck.Contains('Linux workbench code:')) 'Launcher does not show executing Linux Git identity'
    Assert-True ($markerCheck.Contains('--exec /bin/bash -il')) 'Penguins must open an actual interactive Linux shell'
    Assert-True ($markerCheck.Contains('--cd /home/$LinuxUser')) 'WSL fallback must use absolute Linux home, never tilde'
    Assert-True (-not $markerCheck.Contains('Manual start: wsl -d $DistroName -u $LinuxUser --cd ~')) 'WSL tilde fallback reintroduced'
    Assert-True (-not $markerCheck.Contains('bash ./bin/aiw-nemo')) 'Penguin must not auto-start AIW menu'
    Assert-True ($markerCheck.Contains('git status --porcelain')) 'Launcher does not report dirty Linux checkouts'
    Assert-True (-not $markerCheck.Contains('git fetch')) 'Shortcut launcher must not fetch repository automatically'
    Assert-True (-not $markerCheck.Contains('git pull')) 'Shortcut launcher must not silently update Linux'
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
    Write-Host '[OK] Two NemoClaw penguins: workbench/home shell, idempotence, ownership and WSL identity.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
