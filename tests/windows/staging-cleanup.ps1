#requires -Version 7.4
# No WSL, elevation or installer execution required.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../bootstrap/windows/Filesystem.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aiw-staging-test-' + [Guid]::NewGuid().ToString('N'))
$state = Join-Path $fixture 'state'
$stage = Join-Path $state 'source'
$foreign = Join-Path $fixture 'foreign'
New-Item -ItemType Directory -Path $stage, $foreign -Force | Out-Null
Set-Content -LiteralPath (Join-Path $stage 'old.txt') -Value 'disposable'
Set-Content -LiteralPath (Join-Path $foreign 'keep.txt') -Value 'authoritative'

try {
    # Interpose a transient native Windows sharing violation on the first
    # Remove-Item call without requiring Defender to be present on CI.
    $script:removeCalls = 0
    function Remove-Item {
        [CmdletBinding()]
        param([string]$LiteralPath, [switch]$Recurse, [switch]$Force)
        $script:removeCalls++
        if ($script:removeCalls -eq 1) {
            throw [IO.IOException]::new('simulated sharing violation')
        }
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Recurse:$Recurse -Force:$Force -ErrorAction Stop
    }

    Assert-True (Remove-AiwOwnedStagingTree -Path $stage -StateRoot $state -RetryDelaysMs @(0, 0, 0)) 'Transient stage lock did not recover'
    Assert-True ($script:removeCalls -eq 2) 'Expected bounded retry after one failure'
    Assert-True (-not (Test-Path -LiteralPath $stage)) 'Stage not removed'
    Assert-True ((Get-Content -LiteralPath (Join-Path $foreign 'keep.txt')) -eq 'authoritative') 'Foreign data was modified'
    Assert-True (Remove-AiwOwnedStagingTree -Path $stage -StateRoot $state -RetryDelaysMs @(0)) 'Repeated cleanup was not idempotent'

    $blocked = Join-Path $state 'source'
    New-Item -ItemType Directory -Path $blocked -Force | Out-Null
    function Remove-Item {
        [CmdletBinding()]
        param([string]$LiteralPath, [switch]$Recurse, [switch]$Force)
        $script:removeCalls++
        throw [IO.IOException]::new('persistent sharing violation')
    }
    Assert-True (-not (Remove-AiwOwnedStagingTree -Path $blocked -StateRoot $state -RetryDelaysMs @(0, 0))) 'Persistent lock was not reported'
    Assert-True (Test-Path -LiteralPath $blocked) 'Locked stage should remain for later cleanup'

    $refused = $false
    try {
        Remove-AiwOwnedStagingTree -Path $foreign -StateRoot $state -RetryDelaysMs @(0) | Out-Null
    }
    catch { $refused = $true }
    Assert-True $refused 'Out-of-scope path was not refused'
    Write-Host 'Windows installer staging cleanup tests passed.'
}
finally {
    Remove-Item Function:\Remove-Item -ErrorAction SilentlyContinue
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
