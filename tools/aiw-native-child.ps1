#Requires -Version 7.4
<#
AI Workstation native process child. Executed by Process Compose, not the menu.
Keeps native service command and DPAPI credential references out of public Git.
This script runs one foreground process and returns its exit code to supervisor.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [Parameter(Mandatory)][ValidateSet('strata', 'dispatcher', 'caddy', 'open-webui')][string]$Service
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-HostConfig {
    if (-not [IO.File]::Exists($Config)) { throw 'Private native host configuration not found.' }
    return (Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json -AsHashtable)
}

function Read-DpapiValue([string]$Path) {
    if (-not [IO.File]::Exists($Path) -or -not $Path.EndsWith('.dpapi', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Referenced DPAPI file missing or invalid.'
    }
    $cipher = [IO.File]::ReadAllText($Path).Trim()
    $secure = ConvertTo-SecureString -String $cipher
    return [System.Net.NetworkCredential]::new('local', $secure).Password
}

try {
    $cfg = Read-HostConfig
    $svc = $cfg.services[$Service]
    if ($null -eq $svc -or -not [bool]$svc.enabled) {
        throw 'Service has not been enabled in private configuration.'
    }
    $exe = [string]$svc.executable
    $cwd = [string]$svc.working_directory
    if (-not [IO.File]::Exists($exe) -or -not [IO.Directory]::Exists($cwd)) {
        throw 'Configured executable or working directory is unavailable.'
    }
    if ($Service -eq 'strata') {
        $guard = Join-Path $PSScriptRoot 'aiw-native-integrity.ps1'
        if (-not (Test-Path -LiteralPath $guard -PathType Leaf)) {
            throw 'Required Strata integrity verifier is missing.'
        }
        & $guard -Config $Config -Service strata
        if ($LASTEXITCODE -ne 0) {
            throw 'Strata launch is not locally approved; native process was not created.'
        }
    }
    foreach ($item in $svc.environment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable([string]$item.Key, [string]$item.Value, 'Process')
    }
    foreach ($item in $svc.secret_environment.GetEnumerator()) {
        $secret = Read-DpapiValue ([string]$item.Value)
        [Environment]::SetEnvironmentVariable([string]$item.Key, $secret, 'Process')
        Remove-Variable secret -ErrorAction SilentlyContinue
    }
    $arguments = @($svc.arguments | ForEach-Object { [string]$_ })
    Set-Location -LiteralPath $cwd
    & $exe @arguments
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 1 }
    exit [int]$code
}
catch {
    # Never include private config values, native subprocess stderr or credentials.
    [Console]::Error.WriteLine('[XX] Native service launch failed; verify the private executable, DPAPI account, and process settings.')
    exit 1
}
