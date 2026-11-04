#Requires -Version 7.4
# Real user-facing Windows workbench regression: task-based navigation,
# first-time private setup, S02 key actions, back/help and no surprise starts.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testFolder = Join-Path $env:RUNNER_TEMP ('aiw-menu-' + [guid]::NewGuid().ToString('N'))
$env:AIW_SERVICES_DIR = $testFolder
$global:aiwMenuAnswers = @(
    '2',                  # Set up or change this computer
    '1', 'y', 'n', 'n',     # First time; allow init; decline download and opening editor
    '2',                  # Friendly private configuration summary
    '0',                  # Back to main menu
    '1', '?', '0',         # Visit service operations, no real Start
    '3',                  # Application access keys
    '1', 'goose-research', # Create individual key
    '2',                  # List
    '3', '1', 'y',         # Copy original key for selected client to clipboard
    '4', 'y',              # Prepare hash-only registry
    '6', '1', 'goose-core',# Rename the same key (keep ciphertext)
    '2',                  # Verify renamed
    '4', 'y',              # Re-render hash-only registry after rename
    '0',                  # Back
    '4', '1', '2', '0',    # Help: services, identity explanations; back
    '?', 'q'              # Redisplay root once, then quit
)
$global:aiwMenuIndex = 0
function Read-Host {
    param([string]$Prompt)
    if ($global:aiwMenuIndex -ge $global:aiwMenuAnswers.Length) {
        throw 'Workbench did not exit cleanly; unexpected extra question.'
    }
    $answer = $global:aiwMenuAnswers[$global:aiwMenuIndex]
    $global:aiwMenuIndex++
    return $answer
}

try {
    $menuOutput = (& (Join-Path $root 'bootstrap/windows/Services.ps1') 6>&1) -join [Environment]::NewLine
    $headerCount = ([regex]::Matches($menuOutput, '=== AI Workstation \| Windows inference host ===')).Count
    if ($headerCount -ne 6) {
        throw "Main menu appeared $headerCount times; expected initial/back/explicit-help pattern."
    }
    if ($global:aiwMenuIndex -ne $global:aiwMenuAnswers.Length) {
        throw "Unexpected unused menu answers: $global:aiwMenuIndex / $($global:aiwMenuAnswers.Length)"
    }
    foreach ($needle in @(
        'First-time setup', 'View service configuration summary', 'Edit service startup settings',
        'Start all enabled services', 'Open the live status', 'Copy an application API key',
        'Strata: local model inference', 'Dispatcher digest registry'
    )) {
        if ($menuOutput -notmatch [regex]::Escape($needle)) {
            throw "Missing task-oriented explanation: $needle"
        }
    }
    $registryFile = Join-Path $testFolder 'clients.json'
    $key = Join-Path $testFolder 'secrets/goose-core.dpapi'
    if (-not (Test-Path -LiteralPath $registryFile) -or -not (Test-Path -LiteralPath $key)) {
        throw 'Workbench did not prepare a private client key and digest registry.'
    }
    $cfg = Get-Content -LiteralPath $registryFile -Raw | ConvertFrom-Json
    if ($cfg.clients.Count -ne 1 -or $cfg.clients[0].id -cne 'goose-core' -or
        $cfg.clients[0].token_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Workbench did not rename client and render a correct one-way token hash.'
    }
    $original = Get-Clipboard -Raw
    if (-not $original) { throw 'Workbench did not copy original client key to clipboard.' }
    $digest = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($original))
    ).ToLowerInvariant()
    if ($cfg.clients[0].token_sha256 -cne $digest) {
        throw 'Original clipboard key does not match the rendered client digest.'
    }
    if (Test-Path -LiteralPath (Join-Path $testFolder 'runtime/process-compose-windows.json')) {
        throw 'Merely visiting setup/access menus started a supervisor unexpectedly.'
    }
    Write-Host '[PASS] Windows workbench setup, keys, clipboard, nested navigation and concise menu behavior.'
}
finally {
    Set-Clipboard -Value '' -ErrorAction SilentlyContinue
    Remove-Variable aiwMenuAnswers -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable aiwMenuIndex -Scope Global -ErrorAction SilentlyContinue
    Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testFolder -Recurse -Force -ErrorAction SilentlyContinue
}
