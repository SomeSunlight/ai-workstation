#Requires -Version 7.4
# Issue #53: synthetic offline approval, tampering, direct launch and rollback.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$guard = Join-Path $root 'tools/aiw-native-integrity.ps1'
$child = Join-Path $root 'tools/aiw-native-child.ps1'
$dir = Join-Path $env:RUNNER_TEMP ('aiw-integrity-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir -Force | Out-Null
try {
    $exe = (Get-Command python.exe -ErrorAction Stop).Source
    $entry = Join-Path $dir 'entry.py'
    $engine = Join-Path $dir 'engine.exe'
    $marker = Join-Path $dir 'launched.txt'
    Set-Content -LiteralPath $entry -Encoding utf8 -Value @'
from pathlib import Path
Path(__file__).with_name("launched.txt").write_text("launched", encoding="utf-8")
'@
    Set-Content -LiteralPath $engine -Encoding utf8 -Value 'synthetic native engine v1'
    $cfgFile = Join-Path $dir 'native-host.json'
    $data = @{
        schema_version = 1
        services = @{
            strata = @{
                enabled = $true
                executable = $exe
                working_directory = $dir
                arguments = @($entry)
                integrity_files = @($entry, $engine)
                environment = @{}
                secret_environment = @{}
            }
        }
    }
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfgFile -Encoding utf8
    $approved = Join-Path $dir 'strata-launch-approved.json'

    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile *> $null
    if ($LASTEXITCODE -eq 0 -or (Test-Path $approved)) {
        throw 'Unapproved native Strata startup was not refused.'
    }
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile -Review
    if ($LASTEXITCODE -ne 0 -or (Test-Path $approved)) {
        throw 'Review should be read-only.'
    }
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile -Approve
    if ($LASTEXITCODE -ne 0) { throw 'Explicit approval failed.' }
    & pwsh -NoProfile -NonInteractive -File $child -Config $cfgFile -Service strata
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $marker)) {
        throw 'Approved Strata direct Python start did not run.'
    }

    Remove-Item -LiteralPath $marker -Force
    Add-Content -LiteralPath $entry -Value '# tampered one-byte-plus change'
    & pwsh -NoProfile -NonInteractive -File $child -Config $cfgFile -Service strata *> $null
    if ($LASTEXITCODE -eq 0 -or (Test-Path $marker)) {
        throw 'Tampered launch file was executed.'
    }
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile -Approve
    if ($LASTEXITCODE -ne 0) { throw 'Explicit update approval failed.' }
    if (@(Get-ChildItem -LiteralPath $dir -Filter 'strata-launch-approved.json.before-*.bak').Count -lt 1) {
        throw 'Update approval did not preserve rollback baseline.'
    }
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile
    if ($LASTEXITCODE -ne 0) { throw 'Updated approved code was rejected.' }
    # Restoring the old code cannot bypass the new approval; restoring the
    # old approval *together* with the old code is the deliberate rollback.
    $entryOriginal = @'
from pathlib import Path
Path(__file__).with_name("launched.txt").write_text("launched", encoding="utf-8")
'@
    Set-Content -LiteralPath $entry -Encoding utf8 -Value $entryOriginal
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile *> $null
    if ($LASTEXITCODE -eq 0) { throw 'Old code passed newly approved updated baseline.' }
    $backup = Get-ChildItem -LiteralPath $dir -Filter 'strata-launch-approved.json.before-*.bak' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Copy-Item -LiteralPath $backup.FullName -Destination $approved -Force
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile
    if ($LASTEXITCODE -ne 0) { throw 'Rollback to prior approved code failed.' }

    $data.services.strata.arguments = @($entry, '--unexpected')
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfgFile -Encoding utf8
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile *> $null
    if ($LASTEXITCODE -eq 0) { throw 'Modified start arguments bypassed approval.' }
    $data.services.strata.executable = Join-Path $env:SystemRoot 'System32/cmd.exe'
    $data.services.strata.arguments = @('/d','/c','echo wrong')
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfgFile -Encoding utf8
    & pwsh -NoProfile -NonInteractive -File $guard -Config $cfgFile -Approve *> $null
    if ($LASTEXITCODE -eq 0) { throw 'Shell/batch launch was accepted as hardened.' }

    # Native AIW starts through a temporary uv helper environment; the
    # Dispatcher must select its own .venv instead of inheriting that path.
    $envEntry = Join-Path $dir 'inspect-env.py'
    $envResult = Join-Path $dir 'virtual-env-observed.txt'
    Set-Content -LiteralPath $envEntry -Encoding utf8 -Value @'
import os
from pathlib import Path
Path(__file__).with_name("virtual-env-observed.txt").write_text(
    os.environ.get("VIRTUAL_ENV", "<unset>"), encoding="utf-8"
)
'@
    $data.services.dispatcher = @{
        enabled = $true
        executable = $exe
        working_directory = $dir
        arguments = @($envEntry)
        environment = @{}
        secret_environment = @{}
    }
    $data.services.caddy = $data.services.dispatcher.Clone()
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cfgFile -Encoding utf8
    $previousVirtualEnv = [Environment]::GetEnvironmentVariable('VIRTUAL_ENV', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('VIRTUAL_ENV', 'C:\aiw\uv\cache\builds-v0\temporary', 'Process')
        & pwsh -NoProfile -NonInteractive -File $child -Config $cfgFile -Service dispatcher
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $envResult)) {
            throw 'Synthetic Dispatcher did not launch.'
        }
        if ((Get-Content -LiteralPath $envResult -Raw) -cne '<unset>') {
            throw 'Dispatcher inherited an unrelated temporary uv VIRTUAL_ENV.'
        }
        & pwsh -NoProfile -NonInteractive -File $child -Config $cfgFile -Service caddy
        if ($LASTEXITCODE -ne 0 -or
            (Get-Content -LiteralPath $envResult -Raw) -cne 'C:\aiw\uv\cache\builds-v0\temporary') {
            throw 'Dispatcher-specific cleanup unexpectedly affected another service.'
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable('VIRTUAL_ENV', $previousVirtualEnv, 'Process')
    }
    Write-Host '[OK] Dispatcher ignores temporary uv VIRTUAL_ENV; other native services retain theirs.'

    Write-Host '[OK] Strata approved start, missing approval, tampering, explicit reapproval, rollback, argv drift, cmd denial.'
}
finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

# Expected negative checks left LASTEXITCODE non-zero; the test itself passed.
exit 0
