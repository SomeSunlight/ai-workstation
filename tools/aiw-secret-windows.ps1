#Requires -Version 7.4
<#
Windows DPAPI credential adapter for aiw-services.py.
The plaintext secret never enters command arguments, Git, YAML or the filesystem.
Runs under the same Windows account that owns the native Dispatcher.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Store', 'Read', 'Protect', 'Copy')][string]$Action,
    [Parameter(Mandatory)][string]$Path
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Action -eq 'Protect') {
    if (-not [IO.File]::Exists($Path)) { throw 'API token file not found.' }
    # Process Compose needs plaintext for --token-file; keep it strictly user-only.
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $sid, [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.AccessControlType]::Allow)
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
    return
}
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
    if ($Action -eq 'Copy') {
        # Explicit operator request: Keepass transfer without printing the token.
        # Windows clipboard history/sync is an OS setting, not controlled here.
        Set-Clipboard -Value $plain -ErrorAction Stop
        return
    }
    [Console]::Out.Write($plain)
}
