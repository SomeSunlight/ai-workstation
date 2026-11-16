#requires -Version 7.4
# No WSL, Docker, Podman or host changes. Reproduce first-boot stderr-first issue.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'bootstrap/windows/WslUserIdentity.ps1')

function Verify-Refused {
    param([string[]]$Stdout, [int]$ExitCode, [string]$Expected)
    $refused = $false
    try {
        Assert-AiwWslDefaultUserIdentity -StandardOutput $Stdout `
            -ExpectedUser 'moresunlight' -DistroName 'AIW-Nemo' -ExitCode $ExitCode
    }
    catch { $refused = $true }
    if (-not $refused) { throw "Identity validation accepted invalid result: $Expected" }
}

# A systemd warning is stderr. The correct stdout is authoritative.
$wslStderr = "wsl: Failed to start the systemd user session for 'moresunlight'. See journalctl for more details."
$wslStdout = @('moresunlight')
Assert-AiwWslDefaultUserIdentity -StandardOutput $wslStdout `
    -ExpectedUser 'moresunlight' -DistroName 'AIW-Nemo' -ExitCode 0
if ($wslStderr -notmatch 'systemd user session') {
    throw 'Test fixture must reproduce reported WSL systemd warning.'
}
Verify-Refused -Stdout @('root') -ExitCode 0 -Expected 'wrong default user'
Verify-Refused -Stdout @($wslStderr) -ExitCode 0 -Expected 'stderr passed as username'
Verify-Refused -Stdout @('moresunlight', $wslStderr) -ExitCode 0 -Expected 'mixed stdout and stderr'
Verify-Refused -Stdout @('moresunlight') -ExitCode 1 -Expected 'failed WSL process'

# Reproduce owner flight NemoClaw_05.log after successful WSL 3.0.5:
# wsl.exe writes correct stdout and an EMPTY stderr redirection file.
# Get-Content -Raw then yields $null; the former direct .Trim() crashed.
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aiw-wsl-stderr-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    $emptyFile = Join-Path $fixture 'empty.stderr.log'
    [IO.File]::WriteAllBytes($emptyFile, [byte[]]@())
    $emptyText = Get-AiwWslStderrText -Path $emptyFile
    if ($null -eq $emptyText -or $emptyText -cne '') {
        throw 'Empty WSL stderr should be returned as an empty string.'
    }
    $warningFile = Join-Path $fixture 'warning.stderr.log'
    [IO.File]::WriteAllText($warningFile, " `n$wslStderr`r`n ")
    if ((Get-AiwWslStderrText -Path $warningFile) -cne $wslStderr) {
        throw 'Real WSL systemd warning must be preserved after trimming.'
    }
    $missing = Get-AiwWslStderrText -Path (Join-Path $fixture 'missing.log')
    if ($null -eq $missing -or $missing -cne '') {
        throw 'Absent WSL stderr should be an empty string.'
    }
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

$installer = Get-Content (Join-Path $root 'bootstrap/windows/Install-AiWorkstation.ps1') -Raw
if (-not $installer.Contains('--exec /usr/bin/id -un') -or
    -not $installer.Contains('2> $stderrPath') -or
    -not $installer.Contains('Get-AiwWslStderrText -Path $stderrPath') -or
    -not $installer.Contains('Assert-AiwWslDefaultUserIdentity')) {
    throw 'Installer does not use separate WSL stdout/stderr and default-identity validation.'
}
if ($installer.Contains("Select-Object -First 1")) {
    throw 'Old first-line parsing may silently select a WSL error as username.'
}
Write-Host '[OK] WSL stdout/default-user identity and zero-byte stderr parsing work under strict mode.'
