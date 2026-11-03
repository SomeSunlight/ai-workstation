#Requires -Version 7.4
# Non-invasive native-host renderer regression. No AI service is launched.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$temp = Join-Path $env:RUNNER_TEMP ('aiw-native-host-' + [guid]::NewGuid().ToString('N'))
$env:AIW_SERVICES_DIR = $temp
try {
    & (Join-Path $root 'bootstrap/windows/Services.ps1') init
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host init
    $path = Join-Path $temp 'native-host.json'
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    $exe = (Get-Command pwsh).Source
    $cwd = Split-Path -Parent $exe
    $ports = @{ strata = 19881; dispatcher = 19882; caddy = 19883 }
    foreach ($name in @('strata', 'dispatcher', 'caddy')) {
        $item = $data.services[$name]
        $item.executable = $exe
        $item.working_directory = $cwd
        $item.arguments = @('-NoProfile', '-NonInteractive', '-Command', 'exit 0')
        $item.listen_ports = @($ports[$name])
        $item.readiness.url = 'http://127.0.0.1:' + $ports[$name] + '/'
        $item.readiness.expected_status = 200
    }
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host render
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host preflight
    $project = Join-Path $temp 'process-compose.yaml'
    $yaml = Get-Content -LiteralPath $project -Raw
    foreach ($name in @('strata', 'dispatcher', 'caddy')) {
        if ($yaml -notmatch "(?m)^\s{2}$($name):") {
            throw "Service $name missing from project."
        }
    }
    if ($yaml -notmatch 'condition: process_healthy' -or $yaml -notmatch 'disabled: true') {
        throw 'Native project lacks dependencies or safe disabled defaults.'
    }
    # Explicitly changing private input without re-rendering must fail.
    $data.services.caddy.arguments = @('changed')
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
    $rejected = $false
    try { & (Join-Path $root 'bootstrap/windows/Services.ps1') host preflight }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Stale service definitions were accepted.' }
    # A deliberately rejected native CLI leaves LASTEXITCODE=1. The expected
    # negative test passed; do not make the CI PowerShell step fail as a result.
    $global:LASTEXITCODE = 0
    # No real service start is permitted by the production security gate.
    Write-Host '[PASS] Native host init, render, preflight, dependency and drift refusal.'
}
finally {
    Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
