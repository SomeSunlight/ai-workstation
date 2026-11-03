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
    $ports = @{ strata = 19881; dispatcher = 19882; caddy = 19883; 'open-webui' = 19884 }
    foreach ($name in @('strata', 'dispatcher', 'caddy', 'open-webui')) {
        $item = $data.services[$name]
        $item.executable = $exe
        $item.working_directory = $cwd
        $item.arguments = @('-NoProfile', '-NonInteractive', '-Command', 'exit 0')
        $item.required_paths = @($cwd)
        $item.listen_ports = @($ports[$name])
        $item.readiness.url = 'http://127.0.0.1:' + $ports[$name] + '/'
        $item.readiness.expected_status = 200
        if ($name -in @('strata', 'open-webui')) { $item.enabled = $true }
    }
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host render
    # Verify the real pinned Windows Process Compose executable accepts the
    # generated dependency/health schema (dry-run; no child process start).
    & (Join-Path $root 'bootstrap/windows/Services.ps1') install
    & (Join-Path $root 'bootstrap/windows/Services.ps1') check
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host preflight
    $project = Join-Path $temp 'process-compose.yaml'
    $yaml = Get-Content -LiteralPath $project -Raw
    foreach ($name in @('strata', 'dispatcher', 'caddy')) {
        if ($yaml -notmatch "(?m)^\s{2}$($name):") {
            throw "Service $name missing from project."
        }
    }
    if ($yaml -notmatch 'condition: process_healthy' -or $yaml -notmatch 'disabled: true' -or $yaml -notmatch 'open-webui:') {
        throw 'Native project lacks dependencies or safe disabled defaults.'
    }
    # An independently owned listener must block the full-stack preflight.
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, [int]$ports.strata)
    $listener.Start()
    try {
        $collisionRejected = $false
        try { & (Join-Path $root 'bootstrap/windows/Services.ps1') host preflight }
        catch { $collisionRejected = $true }
        if (-not $collisionRejected) { throw 'An already-owned native service port was accepted.' }
    }
    finally { $listener.Stop() }
    $global:LASTEXITCODE = 0
    # Existing unpatched Process Compose may still validate but must NOT start
    # a real native host project, even when its processes are disabled.
    $launchRejected = $false
    try { & (Join-Path $root 'bootstrap/windows/Services.ps1') up }
    catch { $launchRejected = $true }
    if (-not $launchRejected) { throw 'Unpatched Process Compose was allowed to start native host.' }
    if (Test-Path (Join-Path $temp 'runtime/process-compose-windows.json')) {
        throw 'Forbidden native host start created a supervisor ownership record.'
    }
    $global:LASTEXITCODE = 0
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
