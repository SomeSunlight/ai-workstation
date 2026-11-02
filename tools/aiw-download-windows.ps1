#Requires -Version 7.4
<#
Windows native HTTPS fallback when Python urllib cannot reach GitHub release
assets using this host's normal proxy/TLS setup. Never relaxes certificate
verification or downloads to the final executable path. Python verifies the
centrally pinned SHA-256 before extracting the downloaded archive.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)][string]$Destination
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$parsed = [uri]$Uri
if ($parsed.Scheme -ne 'https' -or $parsed.Host -ne 'github.com' -or
    -not $parsed.AbsolutePath.StartsWith('/F1bonacc1/process-compose/releases/download/')) {
    throw 'Refusing non-official Process Compose download URL.'
}
if (Test-Path -LiteralPath $Destination) {
    throw 'Refusing to overwrite an existing download destination.'
}

try {
    Invoke-WebRequest -Uri $Uri -OutFile $Destination -TimeoutSec 45 -MaximumRedirection 10 -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        throw 'Download returned without creating archive.'
    }
}
catch {
    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    throw 'Native Windows HTTPS download failed; inspect network/proxy/TLS policy.'
}
