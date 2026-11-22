#Requires -Version 7.4
# Offline WSL mock: prove immutable-pin handoff before any vendor action.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry = Join-Path $root 'bootstrap/windows/Invoke-LinuxWorkstation.ps1'
$settings = Get-Content (Join-Path $root 'config/linux-project.json') -Raw | ConvertFrom-Json
$expected = [string]$settings.commit
if ($expected -cnotmatch '^[a-f0-9]{40}$') { throw 'Missing immutable Linux pin' }
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('aiw-linux-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$mock = Join-Path $tmp 'fake-wsl.ps1'
$env:MOCK_WSL_TRACE = Join-Path $tmp 'calls.log'
$env:MOCK_LINUX_SHA = $expected
$script = @'
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$line = $Arguments -join ' '
Add-Content -LiteralPath $env:MOCK_WSL_TRACE -Value $line
if ($line -match '/etc/aiw-install-profile') { 'nemoclaw-podman'; exit 0 }
if ($line -match 'rev-parse HEAD') { $env:MOCK_LINUX_SHA; exit 0 }
if ($line -match 'status --porcelain') { exit 0 }
if ($line -match './install.sh --version') { 'ai-workstation-linux 0.1.0 (detached@abcdef0)'; exit 0 }
if ($line -match './install.sh status') { 'Linux status (mock)'; exit 0 }
if ($line -match './install.sh verify') { 'Linux verify (mock)'; exit 0 }
throw "Unexpected Windows->Linux operation: $line"
'@
Set-Content -LiteralPath $mock -Value $script -Encoding utf8
try {
    $output = @(& $entry -WslExecutable $mock -Action Version)
    if (-not (($output -join ' ') -match 'ai-workstation-linux 0\.1\.0')) {
        throw 'Version did not reach Linux candidate through pinned handoff'
    }
    $output = @(& $entry -WslExecutable $mock -Action Status)
    if (-not (($output -join ' ') -match 'Linux status')) { throw 'Status not delegated' }
    $output = @(& $entry -WslExecutable $mock -Action Verify)
    if (-not (($output -join ' ') -match 'Linux verify')) { throw 'Verify not delegated' }
    $before = (Get-Content -LiteralPath $env:MOCK_WSL_TRACE).Count
    $env:MOCK_LINUX_SHA = '0000000000000000000000000000000000000000'
    $refused = $false
    try { & $entry -WslExecutable $mock -Action Status | Out-Null }
    catch { $refused = $true }
    if (-not $refused) { throw 'Mismatched Linux commit unexpectedly accepted' }
    $after = @(Get-Content -LiteralPath $env:MOCK_WSL_TRACE)
    if ($after.Count -ne $before + 2) { throw 'Wrong-ref probe unexpectedly invoked Linux entrypoint' }
    if ((@($after | Where-Object { $_ -match 'install.sh' })).Count -ne 3) {
        throw 'Mismatched Linux commit invoked installer/CLI'
    }
    if (($after -join '\n') -match 'fetch|pull|onboard|destroy|rebuild') {
        throw 'Windows helper attempted an implicit update or destructive action'
    }
    Write-Host '[OK] Windows Linux handoff: pinned version/status/verify, mismatch fails closed.'
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:MOCK_WSL_TRACE -ErrorAction SilentlyContinue
    Remove-Item Env:MOCK_LINUX_SHA -ErrorAction SilentlyContinue
}
