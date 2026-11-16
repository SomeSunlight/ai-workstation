# Offline Windows regression: a service manifest may be readable but locked
# against replacement. The failed client add must not leave an orphan DPAPI key.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$tool = Join-Path $root 'tools/aiw-services.py'
$oldDir = $env:AIW_SERVICES_DIR
$dir = Join-Path $env:RUNNER_TEMP ('aiw-client-recovery-' + [Guid]::NewGuid().ToString('N'))
$env:AIW_SERVICES_DIR = $dir

function Invoke-ClientTool([string[]]$ToolArgs) {
    # Capture the subprocess exit status and sanitized output. Never output keys.
    $ErrorActionPreference = 'Continue'
    try {
        $output = & uv run --no-project --with 'PyYAML==6.0.3' python $tool @ToolArgs 2>&1 | Out-String
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = 'Stop'
    }
    return @{ Output = $output; ExitCode = $code }
}

try {
    $setup = Invoke-ClientTool @('init')
    if ($setup.ExitCode -ne 0) { throw "Fixture init failed: $($setup.Output)" }
    $first = Invoke-ClientTool @('client', 'add', 'existing-client', '--policy', 'default')
    if ($first.ExitCode -ne 0) { throw "Fixture client failed: $($first.Output)" }
    $render = Invoke-ClientTool @('client', 'render')
    if ($render.ExitCode -ne 0) { throw "Fixture render failed: $($render.Output)" }

    $manifest = Join-Path $dir 'services.yaml'
    $hashes = Join-Path $dir 'clients.json'
    $secret = Join-Path $dir 'secrets/locked-client.dpapi'
    $initialManifest = [Convert]::ToBase64String([IO.File]::ReadAllBytes($manifest))
    $initialHashes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($hashes))

    # FileShare.Read permits Python's config read, but refuses the subsequent
    # rename/replacement of services.yaml while we retain the handle.
    $handle = [IO.File]::Open($manifest, [IO.FileMode]::Open,
                              [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $failed = Invoke-ClientTool @('client', 'add', 'locked-client', '--policy', 'passthrough')
    }
    finally {
        $handle.Dispose()
    }
    if ($failed.ExitCode -eq 0) { throw 'Locked manifest unexpectedly accepted new client.' }
    if ($failed.Output -notmatch 'services\.yaml' -or
        $failed.Output -notmatch '(WinError|errno)\s*\d+') {
        throw "Missing actionable sanitized write diagnostic: $($failed.Output)"
    }
    if ($failed.Output -notmatch 'rolled back') {
        throw "No rollback confirmation: $($failed.Output)"
    }
    if (Test-Path -LiteralPath $secret) { throw 'Orphan DPAPI key remained after failed add.' }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($manifest)) -ne $initialManifest) {
        throw 'Failed operation changed the client manifest.'
    }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($hashes)) -ne $initialHashes) {
        throw 'Failed operation modified client hash registry.'
    }

    $retry = Invoke-ClientTool @('client', 'add', 'locked-client', '--policy', 'passthrough')
    if ($retry.ExitCode -ne 0) { throw "Retry after unlocking failed: $($retry.Output)" }
    if (-not (Test-Path -LiteralPath $secret)) { throw 'Retry did not save the DPAPI key.' }
    if ((Get-Content -LiteralPath $manifest -Raw) -notmatch 'locked-client') {
        throw 'Retry did not register the client.'
    }
    Write-Host '[OK] Locked Windows manifest fails with diagnostics, rolls back and retries.'
}
finally {
    $env:AIW_SERVICES_DIR = $oldDir
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
