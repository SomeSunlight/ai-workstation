#Requires -Version 7.4
# Windows-native aiw root invocation and opt-in user PATH registration.
# Works in a disposable GitHub Windows runner; never starts native services.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$origLocal = $env:LOCALAPPDATA
$origUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$origPath = $env:Path
$origAiwDir = [Environment]::GetEnvironmentVariable('AIW_SERVICES_DIR', 'Process')
$temp = Join-Path $env:RUNNER_TEMP ('aiw-short-command-' + [Guid]::NewGuid().ToString('N'))
$env:LOCALAPPDATA = Join-Path $temp 'AppData'
$env:AIW_SERVICES_DIR = Join-Path $temp 'services'
New-Item -Path $env:LOCALAPPDATA -ItemType Directory -Force | Out-Null
$rootLauncher = Join-Path $root 'aiw.cmd'
$shimDir = Join-Path $env:LOCALAPPDATA 'AIWorkstation\bin'
$shim = Join-Path $shimDir 'aiw.cmd'

try {
    $result = (& $rootLauncher init) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $result -notmatch 'Initialized:') {
        throw 'The checkout-local .\aiw CLI did not reach native AIW initialization.'
    }
    $result = (& $rootLauncher where) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $result -notmatch 'Configuration:') {
        throw 'The checkout-local .\aiw CLI did not forward arguments.'
    }
    & $rootLauncher register
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $shim)) {
        throw 'Native aiw command registration failed.'
    }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike ('*' + $shimDir + '*')) {
        throw 'Native aiw shim directory not registered in per-user PATH.'
    }
    $env:Path = $shimDir + ';' + $env:Path
    $where = (& aiw where) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $where -notmatch 'Configuration:') {
        throw 'The registered unqualified aiw command did not forward to the current checkout.'
    }
    & $rootLauncher unregister
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $shim)) {
        throw 'Native aiw command unregister failed.'
    }
    Write-Host '[PASS] Native Windows .\aiw and user-scoped aiw registration/forwarding/unregister.'
}
finally {
    [Environment]::SetEnvironmentVariable('Path', $origUserPath, 'User')
    $env:Path = $origPath
    $env:LOCALAPPDATA = $origLocal
    if ($null -eq $origAiwDir) {
        Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    }
    else {
        $env:AIW_SERVICES_DIR = $origAiwDir
    }
    Remove-Item -LiteralPath $temp -Force -Recurse -ErrorAction SilentlyContinue
}
