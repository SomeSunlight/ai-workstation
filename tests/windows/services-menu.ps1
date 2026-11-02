#Requires -Version 7.4
# Real PowerShell menu regression: a one-element switch result must remain
# an argv array under StrictMode, and 'q' must exit the menu cleanly.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testFolder = Join-Path $env:RUNNER_TEMP ('aiw-menu-' + [guid]::NewGuid().ToString('N'))
$env:AIW_SERVICES_DIR = $testFolder
$script:menuAnswers = @('2', '10', 'goose-laptop', '11', '12', '1', 'q')
$script:answerIndex = 0

# Using a real child script here (instead of a parser-only check) reproduces
# exactly the original failure at menu selection 2.
function Read-Host {
    param([string]$Prompt)
    if ($script:answerIndex -ge $script:menuAnswers.Length) {
        throw 'Menu did not exit after q; unexpected extra prompt.'
    }
    $answer = $script:menuAnswers[$script:answerIndex]
    $script:answerIndex++
    return $answer
}

try {
    & (Join-Path $root 'bootstrap/windows/Services.ps1')
    if ($script:answerIndex -ne $script:menuAnswers.Length) {
        throw "Menu skipped an action or did not read q: $script:answerIndex"
    }
    $config = Join-Path $testFolder 'services.yaml'
    $clientsFile = Join-Path $testFolder 'clients.json'
    $clientSecret = Join-Path $testFolder 'secrets/goose-laptop.dpapi'
    if (-not (Test-Path $config) -or -not (Test-Path $clientsFile) -or -not (Test-Path $clientSecret)) {
        throw 'Menu failed to initialize private YAML or generate named S02 client.'
    }
    $doc = Get-Content $clientsFile -Raw | ConvertFrom-Json
    if ($doc.clients.Count -ne 1 -or $doc.clients[0].id -ne 'goose-laptop' -or
        $doc.clients[0].token_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Menu did not generate the correct one-client S02 hash-only JSON.'
    }
    Write-Host '[PASS] Menu selection 2, 10, 11, 12, 1 and q under StrictMode.'
}
finally {
    Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    Remove-Item -Path $testFolder -Recurse -Force -ErrorAction SilentlyContinue
}
