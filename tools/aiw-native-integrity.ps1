#Requires -Version 7.4
<#
AI Workstation: machine-local approval for a native Strata launch (#53).
Review and approval are explicit, stopped-host operations. Verification runs
before the service is created, without network, package managers or secrets.
#>
[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
    [Parameter(Mandatory)][string]$Config,
    [ValidateSet('strata')][string]$Service = 'strata',
    [Parameter(ParameterSetName = 'Review')][switch]$Review,
    [Parameter(ParameterSetName = 'Approve')][switch]$Approve
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CanonicalFile([string]$Path) {
    if (-not [IO.Path]::IsPathFullyQualified($Path)) {
        throw 'An integrity file path is not absolute.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    $file = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'An integrity entry is not a regular, non-linked file.'
    }
    return $full
}

function Get-Digest([string]$Value) {
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))
    ).ToLowerInvariant()
}

function Get-Candidate([System.Collections.IDictionary]$ServiceConfig) {
    $exe = Get-CanonicalFile ([string]$ServiceConfig.executable)
    $cwd = [IO.Path]::GetFullPath([string]$ServiceConfig.working_directory)
    if (-not [IO.Directory]::Exists($cwd)) {
        throw 'Approved working directory does not exist.'
    }
    $base = [IO.Path]::GetFileName($exe).ToLowerInvariant()
    # A shell/batch/package-manager wrapper can download or replace code at
    # startup. The hardened Strata path must invoke an installed engine or
    # Python interpreter directly, after review of the old batch contents.
    if ($base -in @('cmd.exe','powershell.exe','pwsh.exe','uv.exe',
                    'pip.exe','pip3.exe','curl.exe','wget.exe','git.exe') -or
        [IO.Path]::GetExtension($exe).ToLowerInvariant() -in @('.bat','.cmd','.ps1')) {
        throw 'Hardened Strata launch must not use shell, batch or installer wrappers.'
    }
    $argv = @($ServiceConfig.arguments | ForEach-Object { [string]$_ })
    for ($i = 0; $i -lt $argv.Count; $i++) {
        if ($argv[$i] -in @('-c','-m') -and $i + 1 -lt $argv.Count) {
            if ($argv[$i] -eq '-c' -or $argv[$i + 1] -match '^(pip|uv|ensurepip)(\\.|$)') {
                throw 'Hardened Strata startup cannot invoke Python install/inline-code commands.'
            }
        }
    }
    $extra = @($ServiceConfig.integrity_files)
    if ($extra.Count -lt 1) {
        throw 'Strata requires integrity_files for its code-bearing start chain.'
    }
    $paths = @($exe) + @($extra | ForEach-Object { Get-CanonicalFile ([string]$_) })
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $files = @()
    foreach ($path in $paths) {
        if (-not $seen.Add($path)) {
            throw 'Duplicate integrity file path.'
        }
        $files += [ordered]@{
            path = $path
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    return [ordered]@{
        schema_version = 1
        executable = $exe
        working_directory = $cwd
        arguments_sha256 = Get-Digest (ConvertTo-Json -InputObject $argv -Compress -Depth 4)
        files = $files
    }
}

try {
    $configFile = Get-CanonicalFile $Config
    $folder = [IO.Path]::GetDirectoryName($configFile)
    $manifest = Join-Path $folder 'strata-launch-approved.json'
    $configData = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json -AsHashtable
    if (-not $configData.services -or -not $configData.services.strata) {
        throw 'Strata service missing from private native-host configuration.'
    }
    $candidate = Get-Candidate $configData.services.strata
    if ($Review) {
        Write-Host 'Proposed native Strata launch approval (no changes made):'
        Write-Host "Executable: $($candidate.executable)"
        Write-Host "Working directory: $($candidate.working_directory)"
        Write-Host "Arguments SHA-256: $($candidate.arguments_sha256)"
        foreach ($file in $candidate.files) {
            Write-Host "SHA-256 $($file.sha256)  $($file.path)"
        }
        Write-Host "Compare these values with installed provenance and the previous baseline."
        exit 0
    }
    if ($Approve) {
        # Approval is never part of process start, render, check or preflight.
        # The operator first inspects provenance/hashes with -Review.
        if ([IO.File]::Exists((Join-Path $folder 'runtime/process-compose-windows.json'))) {
            throw 'Host supervisor ownership record present; stop owned services before reapproval.'
        }
        if ([IO.File]::Exists($manifest)) {
            [void](Get-CanonicalFile $manifest)
            $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')
            Copy-Item -LiteralPath $manifest -Destination ($manifest + '.before-' + $stamp + '.bak') -ErrorAction Stop
        }
        $tmp = $manifest + '.new-' + [guid]::NewGuid().ToString('N')
        try {
            [IO.File]::WriteAllText($tmp, ((ConvertTo-Json -InputObject $candidate -Depth 8) + "`n"),
                [Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $tmp -Destination $manifest -Force -ErrorAction Stop
        }
        finally {
            if ([IO.File]::Exists($tmp)) { Remove-Item -LiteralPath $tmp -Force }
        }
        Write-Host '[OK] Explicit local Strata launch approval saved; no process started.'
        exit 0
    }

    if (-not [IO.File]::Exists($manifest)) {
        throw 'No local Strata launch approval; inspect and explicitly approve before startup.'
    }
    [void](Get-CanonicalFile $manifest)
    $approved = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -AsHashtable
    if ($approved.schema_version -ne 1 -or
        -not [string]::Equals([string]$approved.executable, [string]$candidate.executable,
            [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals([string]$approved.working_directory, [string]$candidate.working_directory,
            [StringComparison]::OrdinalIgnoreCase) -or
        $approved.arguments_sha256 -cne $candidate.arguments_sha256) {
        throw 'Strata executable, working directory or arguments differ from approved launch.'
    }
    $actualFiles = @($candidate.files)
    $oldFiles = @($approved.files)
    if ($actualFiles.Count -ne $oldFiles.Count) {
        throw 'Strata launch-chain file list differs from approved baseline.'
    }
    for ($i = 0; $i -lt $actualFiles.Count; $i++) {
        if (-not [string]::Equals([string]$oldFiles[$i].path, [string]$actualFiles[$i].path,
                [StringComparison]::OrdinalIgnoreCase) -or
            $oldFiles[$i].sha256 -cne $actualFiles[$i].sha256) {
            throw "Strata launch-chain hash/path mismatch at entry $($i + 1)."
        }
    }
    Write-Host '[OK] Locally approved Strata executable and launch-chain hashes verified.'
    exit 0
}
catch {
    # No command arguments, credentials or environment values are logged.
    [Console]::Error.WriteLine('[XX] Strata integrity: ' + $_.Exception.Message)
    exit 3
}
