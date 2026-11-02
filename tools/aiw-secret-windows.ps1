#Requires -Version 7.4
<#
Windows DPAPI credential adapter for aiw-services.py.
The plaintext secret never enters command arguments, Git, YAML or the filesystem.
Runs under the same Windows account that owns the native Dispatcher.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Store', 'Read')][string]$Action,
    [Parameter(Mandatory)][string]$Path
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Action -eq 'Store') {
    if ([System.IO.File]::Exists($Path)) {
        throw 'Credential exists; refusing overwrite.'
    }
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Contains([char]10) -or $raw.Contains([char]13)) {
        throw 'Invalid secret input.'
    }
    # Scoped to this Windows user; no key or plain token is stored in YAML.
    $secure = ConvertTo-SecureString -String $raw -AsPlainText -Force
    $ciphertext = ConvertFrom-SecureString -SecureString $secure
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $file = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew,
                                  [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($ciphertext)
        $file.Write($bytes, 0, $bytes.Length)
    }
    finally { $file.Dispose() }
}
else {
    if (-not [System.IO.File]::Exists($Path)) {
        throw 'Credential not found.'
    }
    $encrypted = [System.IO.File]::ReadAllText($Path).Trim()
    $secure = ConvertTo-SecureString -String $encrypted
    $plain = [System.Net.NetworkCredential]::new('unused', $secure).Password
    [Console]::Out.Write($plain)
}
