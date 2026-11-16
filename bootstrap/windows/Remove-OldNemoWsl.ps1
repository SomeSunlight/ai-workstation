#requires -Version 7.4
<#
  Retire ONLY the user-confirmed AIW-Nemo Ubuntu 24.04 or 26.04 test distro.
  This is never called by the installer. WSL unregister permanently destroys
  the selected distro's filesystem, images, data and containers.
#>
[CmdletBinding()]
param([ValidateSet('Status','Remove')][string]$Action = 'Status')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$name = 'AIW-Nemo'
$expected = 'C:\WSL\AIW-Nemo'
$wsl = Join-Path $env:WINDIR 'System32\wsl.exe'
. (Join-Path $PSScriptRoot 'NemoWslRelease.ps1')

function Get-Names {
    $out = @(& $wsl --list --quiet 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'WSL list failed; no changes made.' }
    return @($out | ForEach-Object { ([string]$_ -replace [char]0, '').Trim() } | Where-Object { $_ })
}
function Check-Ownership {
    $reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    $match = @(Get-ChildItem -LiteralPath $reg | ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath } | Where-Object { $_.DistributionName -ceq $name })
    if ($match.Count -ne 1) { throw "Missing or ambiguous registration for $name." }
    $path = [string]$match[0].BasePath
    if ($path.StartsWith('\\?\')) { $path = $path.Substring(4) }
    if ([IO.Path]::GetFullPath($path).TrimEnd('\') -ine [IO.Path]::GetFullPath($expected).TrimEnd('\')) {
        throw "WSL distro '$name' is not registered at the expected path. Refusing."
    }
    $marker = @(& $wsl --distribution $name --user root --exec /bin/cat /etc/aiw-install-profile 2>$null)
    $ownerMark = ($marker -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $ownerMark -cnotin @('nemoclaw', 'nemoclaw-podman')) {
        throw "Wrong ownership marker '$ownerMark'. Refusing to remove an unrelated distro."
    }
    $release = @(& $wsl --distribution $name --user root --exec /bin/cat /etc/os-release 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not read Ubuntu release identity; no changes made.'
    }
    $version = Get-AiwNemoUbuntuVersion -Lines ([string[]]$release)
    return [pscustomobject]@{ Version = $version; Marker = $ownerMark }
}
function Remove-OwnLinks {
    $shell = New-Object -ComObject WScript.Shell
    $folders = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
    foreach ($folder in $folders) {
        $link = Join-Path $folder "NemoClaw Hermes ($name).lnk"
        if (-not (Test-Path -LiteralPath $link -PathType Leaf)) { continue }
        $shortcut = $shell.CreateShortcut($link)
        if ($shortcut.Description -cne "AIW NemoClaw profile: $name") {
            Write-Warning "Customized shortcut retained: $link"
            continue
        }
        Remove-Item -LiteralPath $link -Force
        Write-Host "Removed owned shortcut: $link"
    }
}
if ($name -cnotin @(Get-Names)) {
    Write-Host "Distribution '$name' does not exist; nothing to delete."
    exit 0
}
$identity = Check-Ownership
Write-Host "Verified NemoClaw test: Ubuntu $($identity.Version), marker '$($identity.Marker)', path $expected."
Write-Warning "Unregister destroys all data/images/volumes inside $name permanently."
Write-Host 'All other WSL distributions and Windows settings remain untouched.'
if ($Action -ne 'Remove') {
    Write-Host 'Status only. To remove it, run this same script with -Action Remove.'
    exit 0
}
$answer = Read-Host "Confirm permanent data loss by typing exactly DELETE AIW-Nemo"
if ($answer -cne 'DELETE AIW-Nemo') { throw 'Confirmation refused. No changes made.' }
& $wsl --unregister $name
if ($LASTEXITCODE -ne 0) { throw 'WSL unregister failed; manual investigation required.' }
if ($name -cin @(Get-Names)) { throw 'WSL still reports this distro after unregister.' }
Write-Host "[OK] Only '$name' was unregistered."
Remove-OwnLinks
if (Test-Path -LiteralPath $expected) {
    $leftovers = @(Get-ChildItem -LiteralPath $expected -Force)
    if ($leftovers.Count -eq 0) {
        Remove-Item -LiteralPath $expected -Force
        Write-Host '[OK] Empty old WSL folder removed.'
    } else {
        Write-Warning "Residual files remain at $expected. No automatic deletion; inspect first."
    }
}
Write-Host '[OK] Legacy WSL distributions were not touched.'
