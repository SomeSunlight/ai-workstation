#requires -Version 7.4
<#
.SYNOPSIS
  Read-only Windows -> separately versioned Linux workstation handoff.
.DESCRIPTION
  Draft migration gate: queries a Linux WSL checkout at an explicitly pinned
  Git commit. It never clones, fetches, pulls, installs, onboards, rebuilds or
  destroys a sandbox; it cannot affect native Windows services.
  Do NOT replace the existing NemoClaw desktop launcher before owner approval.
#>
[CmdletBinding()]
param(
    [ValidateSet('Version', 'Status', 'Verify')]
    [string]$Action = 'Version',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName = 'AIW-Nemo',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser = 'moresunlight',
    [string]$WslExecutable = (Join-Path $env:WINDIR 'System32\wsl.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$configPath = Join-Path $root 'config/linux-project.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Linux project pin is missing: $configPath"
}
$settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
if ($settings.schemaVersion -ne 1 -or $settings.contract -cne 'linux-native-install-status-verify-v1' -or
    $settings.project -cne 'ai-workstation-linux') {
    throw 'Unexpected Linux handoff contract or schema.'
}
$expected = [string]$settings.commit
if ($expected -cnotmatch '^[a-f0-9]{40}$') {
    throw 'Expected Linux commit must be an immutable, 40-character Git SHA.'
}
$repo = [string]$settings.repository
if ($repo -cne 'https://github.com/SomeSunlight/ai-workstation-linux.git') {
    throw 'Linux repository authority mismatch; refusing checkout invocation.'
}
$directory = [string]$settings.workdir
if ($directory -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$') {
    throw 'Unsafe Linux checkout directory in pin configuration.'
}

$marker = @(& $WslExecutable --distribution $DistroName --user root --exec /bin/cat /etc/aiw-install-profile 2>&1)
if ($LASTEXITCODE -ne 0 -or ($marker -join '').Trim() -cne 'nemoclaw-podman') {
    throw "WSL distribution '$DistroName' is missing or not the reviewed NemoClaw profile."
}

$workdir = "/home/$LinuxUser/$directory"
$actualOutput = @(& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /usr/bin/git rev-parse HEAD 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Linux checkout not ready at $workdir. No update attempted. Detail: $($actualOutput -join ' ')"
}
$actual = ($actualOutput -join '').Trim()
if ($actual -cnotmatch '^[a-f0-9]{40}$') {
    throw "Cannot verify Linux checkout revision; no command executed. Output: $actual"
}
Write-Host "Linux project (selected): $($settings.project)@$expected"
Write-Host "Linux checkout (installed): $actual"
if ($actual -cne $expected) {
    throw 'Linux checkout differs from selected immutable revision. No implicit fetch, pull or execution.'
}

$dirty = @(& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /usr/bin/git status --porcelain --untracked-files=normal 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw 'Could not check Linux checkout state; refusing action.'
}
if ($dirty.Count -gt 0) {
    Write-Warning 'Selected Linux checkout has local changes. Stop and review before runtime acceptance.'
    if ($Action -ne 'Version') {
        throw 'Read-only status/verify of a dirty Linux deployment is blocked until reviewed.'
    }
}
$arg = switch ($Action) {
    'Version' { '--version' }
    'Status' { 'status' }
    'Verify' { 'verify' }
}
& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /bin/bash ./install.sh $arg
if ($LASTEXITCODE -ne 0) {
    throw "Linux $Action returned exit code $LASTEXITCODE. No recovery or installer was run."
}
