#Requires -Version 7.4
# Real PowerShell menu regression: a one-element switch result must remain
# an argv array under StrictMode, and 'q' must exit the menu cleanly.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testFolder = Join-Path $env:RUNNER_TEMP ('aiw-menu-' + [guid]::NewGuid().ToString('N'))
$env:AIW_SERVICES_DIR = $testFolder
$global:aiwMenuAnswers = @('2', '10', 'goose-research', '11', '12', '15', '16', '1', 'goose-core', '11', '12', '14', '1', 'y', '1', '?', 'q')
$global:aiwMenuIndex = 0

# Using a real child script here (instead of a parser-only check) reproduces
# exactly the original failure at menu selection 2.
function Read-Host {
    param([string]$Prompt)
    if ($global:aiwMenuIndex -ge $global:aiwMenuAnswers.Length) {
        throw 'Menu did not exit after q; unexpected extra prompt.'
    }
    $answer = $global:aiwMenuAnswers[$global:aiwMenuIndex]
    $global:aiwMenuIndex++
    return $answer
}

try {
    $menuOutput = (& (Join-Path $root 'bootstrap/windows/Services.ps1') 6>&1) -join "`n"
    # One initial menu and one explicit '?' redisplay, NOT a full menu
    # after each action; action delimiters preserve scrollback orientation.
    $headers = ([regex]::Matches($menuOutput, '=== AI Workstation \\| Native services ===')).Count
    if ($headers -ne 2) {
        throw "Menu showed $headers times; expected once + explicit ?."
    }
    if ($menuOutput -notmatch '--- End of action 14') {
        throw 'Menu action boundaries missing from historical output.'
    }
    if ($global:aiwMenuIndex -ne $global:aiwMenuAnswers.Length) {
        throw "Menu skipped an action or did not read q: $global:aiwMenuIndex"
    }
    $config = Join-Path $testFolder 'services.yaml'
    $clientsFile = Join-Path $testFolder 'clients.json'
    $clientSecret = Join-Path $testFolder 'secrets/goose-core.dpapi'
    if (-not (Test-Path $config) -or -not (Test-Path $clientsFile) -or -not (Test-Path $clientSecret)) {
        throw 'Menu failed to initialize private YAML or generate named S02 client.'
    }
    $doc = Get-Content $clientsFile -Raw | ConvertFrom-Json
    if ($doc.clients.Count -ne 1 -or $doc.clients[0].id -ne 'goose-core' -or
        $doc.clients[0].token_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Menu did not generate the correct one-client S02 hash-only JSON.'
    }
    # Clipboard transfer runs in real PowerShell without printing the plaintext.
    $clipboardValue = Get-Clipboard -Raw
    if ([string]::IsNullOrEmpty($clipboardValue)) {
        throw 'No original key copied to clipboard by menu option 14.'
    }
    $clipboardHash = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($clipboardValue))
    ).ToLowerInvariant()
    if ($doc.clients[0].token_sha256 -cne $clipboardHash) {
        throw 'KeePass clipboard key does not match generated S02 digest.'
    }
    Write-Host '[PASS] Menu init/add/list/render/help/rename/clipboard/where/quit under StrictMode.'
}
finally {
    # Clear the temporary clipboard secret on ephemeral CI runners.
    Set-Clipboard -Value '' -ErrorAction SilentlyContinue
    Remove-Variable aiwMenuAnswers -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable aiwMenuIndex -Scope Global -ErrorAction SilentlyContinue
    Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    Remove-Item -Path $testFolder -Recurse -Force -ErrorAction SilentlyContinue
}
