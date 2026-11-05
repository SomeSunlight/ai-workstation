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
    # Native Caddy readiness has no HTTP request or access-log entry.
    # A successful certificate-validated TLS handshake proves the configured
    # HTTPS listener is reachable; route/auth correctness stays a separate
    # explicit acceptance test (401/200 for the S02 gateway).
    if ($Service -eq 'caddy' -and $probe['probe_mode'] -eq 'tls') {
        if ($uri.Scheme -ne 'https' -or $probe.bearer_dpapi) { exit 1 }
        $tcp = [Net.Sockets.TcpClient]::new()
        try {
            $connect = $tcp.ConnectAsync($uri.DnsSafeHost, $uri.Port)
            if (-not $connect.Wait(4000)) { exit 1 }
            $ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false)
            try {
                $options = [Net.Security.SslClientAuthenticationOptions]::new()
                $options.TargetHost = $uri.DnsSafeHost
                $options.CertificateRevocationCheckMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::Online
                $task = $ssl.AuthenticateAsClientAsync($options, [Threading.CancellationToken]::None)
                if (-not $task.Wait(5000)) { exit 1 }
                if ($ssl.IsAuthenticated -and $ssl.IsEncrypted) { exit 0 }
            }
            finally { $ssl.Dispose() }
        }
        finally { $tcp.Dispose() }
        exit 1
    }
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
