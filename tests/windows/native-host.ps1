#Requires -Version 7.4
# Non-invasive native-host renderer regression. No AI service is launched.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$temp = Join-Path $env:RUNNER_TEMP ("aiw-native-O'Brien space-" + [guid]::NewGuid().ToString('N'))
$env:AIW_SERVICES_DIR = $temp
try {
    & (Join-Path $root 'bootstrap/windows/Services.ps1') init
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host init
    # First-time summary must be readable even before start paths are populated.
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host inspect
    $path = Join-Path $temp 'native-host.json'
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    $exe = (Get-Command pwsh).Source
    $cwd = Split-Path -Parent $exe
    $entry = Join-Path $temp "strata's offline entry.py"
    $engine = Join-Path $temp "engine native.exe"
    Set-Content -LiteralPath $entry -Encoding utf8 -Value 'print("synthetic no-service start")'
    Set-Content -LiteralPath $engine -Encoding utf8 -Value 'synthetic native engine content'
    $ports = @{ strata = 19881; dispatcher = 19882; caddy = 19883; 'open-webui' = 19884 }
    foreach ($name in @('strata', 'dispatcher', 'caddy', 'open-webui')) {
        $item = $data.services[$name]
        $item.executable = $exe
        if ($name -eq 'strata') {
            $item.executable = (Get-Command python.exe -ErrorAction Stop).Source
            $item.integrity_files = @($entry, $engine)
            $item.arguments = @($entry)
        }
        $item.working_directory = $cwd
        if ($name -ne 'strata') {
            $item.arguments = @('-NoProfile', '-NonInteractive', '-Command', 'exit 0')
        }
        $item.required_paths = @($cwd)
        if ($name -eq 'open-webui') { $item.environment.DATA_DIR = $cwd }
        $item.listen_ports = @($ports[$name])
        $item.readiness.url = 'http://127.0.0.1:' + $ports[$name] + '/v1/models'
        $item.readiness.expected_status = 200
        if ($name -eq 'caddy') {
            $item.readiness.url = 'https://example.test/v1/models'
            $item.readiness.expected_status = 401
        }
        $item.enabled = $true
    }
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
    # New setup flow: check human-edited JSON before generating launch commands.
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host validate
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host inspect
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host integrity-review
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic Strata review failed.' }
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host integrity-approve
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic Strata approval failed.' }
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host render
    # Verify the real pinned Windows Process Compose executable accepts the
    # generated dependency/health schema (dry-run; no child process start).
    & (Join-Path $root 'bootstrap/windows/Services.ps1') install
    & (Join-Path $root 'bootstrap/windows/Services.ps1') check
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host preflight
    $project = Join-Path $temp 'process-compose.yaml'
    $yaml = Get-Content -LiteralPath $project -Raw
    if ($yaml -notmatch '(?m)^ordered_shutdown: true\s*$') {
        throw 'Native host must stop dependents first and Strata last before supervisor exit.'
    }
    # Shell-free process argv and plainly quoted PowerShell health probes.
    # The temporary host location has both spaces and an apostrophe.
    if ($yaml -notmatch '(?m)^  shell_command: pwsh$' -or
        $yaml -notmatch '(?m)^  shell_argument: -Command$' -or
        $yaml -notmatch '(?m)^    entrypoint:' -or
        $yaml -match 'EncodedCommand' -or $yaml -match 'cmd[.]exe' -or
        $yaml -notmatch "''") {
        throw 'Native Process Compose shell, launch argv or quote-escaping regression.'
    }
    if ($yaml -notmatch 'aiw-native-child[.]ps1' -or
        $yaml -notmatch 'aiw-native-health[.]ps1') {
        throw 'Native entrypoint or health script missing.'
    }
    # Regression: a cold native Strata model load can last 1-2 minutes,
    # so a 3x5-second probe must NOT stop it after 16 seconds.
    $strataConfig = [regex]::Match($yaml, '(?s)(?m)^  strata:\s*\r?\n(.*?)(?=^  dispatcher:)').Groups[1].Value
    if ($strataConfig -notmatch 'failure_threshold: 59' -or
        $strataConfig -notmatch 'initial_delay_seconds: 5' -or
        $strataConfig -notmatch 'period_seconds: 5') {
        throw 'Native Strata cold-start readiness window regressed below ~300 seconds.'
    }
    if ($yaml -notmatch 'log_location:' -or
        $yaml -notmatch 'max_size_mb: 10' -or
        $yaml -notmatch 'max_backups: 5') {
        throw 'Persistent rotated service logs are missing from generated Process Compose.'
    }
    foreach ($name in @('strata','dispatcher','caddy','open-webui')) {
        $logPath = Join-Path $temp ('runtime/logs/' + $name + '.log')
        if (-not $yaml.Contains($logPath)) {
            throw "Persistent output path missing for service $name."
        }
    }
    $strataLog = Join-Path $temp 'runtime/logs/strata.log'
    Set-Content -LiteralPath $strataLog -Value 'synthetic-strata-diagnostic-only'
    $saved = (& (Join-Path $root 'bootstrap/windows/Services.ps1') logs-file strata) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $saved -notmatch 'synthetic-strata-diagnostic-only') {
        throw 'Private saved-log viewer did not recover service output without a running supervisor.'
    }
    foreach ($name in @('strata', 'dispatcher', 'caddy')) {
        if ($yaml -notmatch "(?m)^\s{2}$($name):") {
            throw "Service $name missing from project."
        }
    }
    if ($yaml -notmatch 'condition: process_healthy' -or $yaml -notmatch 'open-webui:') {
        throw 'Native project lacks dependencies or safe disabled defaults.'
    }
    # Operators can extend the grace window in PRIVATE JSON without editing
    # generated Process Compose YAML or changing credential settings.
    $data.services.strata.readiness.startup_grace_seconds = 420
    $data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host validate
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host render
    $customYaml = Get-Content -LiteralPath $project -Raw
    $customStrata = [regex]::Match($customYaml, '(?s)(?m)^  strata:\s*\r?\n(.*?)(?=^  dispatcher:)').Groups[1].Value
    if ($customStrata -notmatch 'failure_threshold: 83') {
        throw 'Custom Strata startup_grace_seconds did not update readiness threshold.'
    }
    & (Join-Path $root 'bootstrap/windows/Services.ps1') check
    # Invalid grace must never be rendered as an implicit 5-minute default.
    $data.services.strata.readiness.startup_grace_seconds = 20
    $data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
    $badGraceRejected = $false
    try { & (Join-Path $root 'bootstrap/windows/Services.ps1') host validate }
    catch { $badGraceRejected = $true }
    if (-not $badGraceRejected) { throw 'Invalid cold-start grace was accepted.' }
    $data.services.strata.readiness.startup_grace_seconds = 420
    $data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
    $global:LASTEXITCODE = 0

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
    # Preview is read-only, then an explicit offline opt-in stages only three
    # readiness changes and backs up the byte-identical original JSON.
    $before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host quiet-probes
    $afterPreview = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($before -cne $afterPreview) { throw 'Quiet-probe preview mutated the private JSON.' }
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host quiet-probes --apply
    $quiet = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    if ($quiet.services.strata.readiness.url -notmatch '/health$' -or
        $quiet.services.dispatcher.readiness.url -notmatch '/health$' -or
        $quiet.services.dispatcher.readiness.bearer_dpapi -ne '' -or
        $quiet.services.caddy.readiness.probe_mode -ne 'tls' -or
        $quiet.services.caddy.readiness.url -ne 'https://example.test/v1/models') {
        throw 'Quiet-probe migration altered wrong private service settings.'
    }
    $originalBackup = Join-Path $temp 'native-host.before-quiet-probes.json'
    if (-not (Test-Path -LiteralPath $originalBackup) -or
        (Get-FileHash -LiteralPath $originalBackup -Algorithm SHA256).Hash -cne $before) {
        throw 'Original private native JSON was not backed up byte-for-byte.'
    }
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host quiet-probes --apply
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host validate
    & (Join-Path $root 'bootstrap/windows/Services.ps1') host render
    & (Join-Path $root 'bootstrap/windows/Services.ps1') check
    $global:LASTEXITCODE = 0
    Write-Host '[PASS] Native host setup, slow readiness, silent probe migration, TLS mode and rollback backup.'
}
finally {
    Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
