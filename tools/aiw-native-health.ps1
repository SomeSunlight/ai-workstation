#Requires -Version 7.4
<#
Secret-safe application-level readiness check for supervised native services.
A Caddy 401 probe (without bearer) is intentionally healthy when configured.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [Parameter(Mandatory)][ValidateSet('strata', 'dispatcher', 'caddy', 'open-webui')][string]$Service
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (-not [IO.File]::Exists($Config)) { exit 1 }
    $cfg = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json -AsHashtable
    $svc = $cfg.services[$Service]
    if ($null -eq $svc -or -not [bool]$svc.enabled) { exit 1 }
    $probe = $svc.readiness
    $uri = [Uri]::new([string]$probe.url, [UriKind]::Absolute)
    if ($uri.Scheme -notin @('http', 'https') -or $uri.UserInfo) { exit 1 }
    $headers = @{}
    $path = [string]$probe.bearer_dpapi
    if ($path) {
        if (-not [IO.File]::Exists($path) -or -not $path.EndsWith('.dpapi', [StringComparison]::OrdinalIgnoreCase)) {
            exit 1
        }
        $protected = [IO.File]::ReadAllText($path).Trim()
        $credential = ConvertTo-SecureString -String $protected
        $original = [Net.NetworkCredential]::new('local', $credential).Password
        $headers['Authorization'] = 'Bearer ' + $original
        Remove-Variable original -ErrorAction SilentlyContinue
    }
    # No redirects, no TLS bypass. A 401 from the protected gateway is valid
    # only if expected_status is deliberately 401.
    $response = Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 5 -NoProxy -ErrorAction Stop
    if ([int]$response.StatusCode -eq [int]$probe.expected_status) { exit 0 }
}
catch {
    # Do not echo headers, responses or private configuration to Process Compose logs.
}
exit 1
