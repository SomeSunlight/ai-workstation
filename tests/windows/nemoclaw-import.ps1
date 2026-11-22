#requires -Version 7.4
# Offline Windows test of observed WSL-import logic. No WSL registration,
# Docker, NemoClaw or privileged host mutation.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'bootstrap/windows/Observe-WslImport.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aiw-wsl-observer-' + [guid]::NewGuid().ToString('N'))
$pwsh = Join-Path $PSHOME 'pwsh.exe'
$diag = Join-Path $fixture 'diagnostics'
$virtualDisk = Join-Path $fixture 'vhdx'
function Assert-True {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
}
try {
    New-Item -ItemType Directory -Path $fixture, $virtualDisk -Force | Out-Null
    $success = Join-Path $fixture 'import-success.ps1'
    Set-Content -LiteralPath $success -Encoding utf8NoBOM -Value @'
Write-Output "WSL mock: import begins"
Start-Sleep -Seconds 2
Write-Output "WSL mock: import complete"
exit 0
'@
    $arguments = @('-NoLogo','-NoProfile','-File', ('"{0}"' -f $success))
    $result = & {
        Invoke-AiwObservedWslImport -Executable $pwsh -Arguments $arguments -LogDirectory $diag -InstallLocation $virtualDisk -HeartbeatSeconds 1
    } 6>&1 | Out-String
    Assert-True ($result.Contains('STILL RUNNING')) "No active-process heartbeat was emitted: $result"
    Assert-True ($result.Contains('exit code: 0')) "No process-exit diagnostic: $result"
    Assert-True ($result.Contains('import complete')) "WSL output was not captured/replayed: $result"

    $failure = Join-Path $fixture 'import-failure.ps1'
    Set-Content -LiteralPath $failure -Encoding utf8NoBOM -Value @'
Write-Error "Synthetic WSL failure"
exit 7
'@
    $arguments = @('-NoLogo','-NoProfile','-File', ('"{0}"' -f $failure))
    $rejected = $false
    try {
        Invoke-AiwObservedWslImport -Executable $pwsh -Arguments $arguments -LogDirectory $diag -InstallLocation $virtualDisk -HeartbeatSeconds 1
    }
    catch {
        $rejected = $_.Exception.Message.Contains('exit code 7')
    }
    Assert-True $rejected 'Nonzero WSL import exit code was accepted'
    Assert-True ((@(Get-ChildItem -LiteralPath $diag -Filter '*.stderr.log')).Count -eq 2) 'Missing retained WSL stderr logs'
    Assert-True ((@(Get-ChildItem -LiteralPath $diag -Filter '*empty-stdin.txt')).Count -eq 0) 'Temporary stdin file was not removed'
    # Reproduce the owner's actual Windows-owned failure without creating
    # a WSL distro. The recovery response must classify and preserve data.
    $registrationTimeout = Join-Path $fixture 'import-register-timeout.ps1'
    Set-Content -LiteralPath $registrationTimeout -Encoding utf8NoBOM -Value @'
Write-Output 'Fehlercode: Wsl/Service/RegisterDistro/WSAETIMEDOUT'
exit 11
'@
    $arguments = @('-NoLogo','-NoProfile','-File', ('"{0}"' -f $registrationTimeout))
    $timeoutMessage = ''
    try {
        Invoke-AiwObservedWslImport -Executable $pwsh -Arguments $arguments -LogDirectory $diag -InstallLocation $virtualDisk -HeartbeatSeconds 1
    }
    catch {
        $timeoutMessage = $_.Exception.Message
    }
    Assert-True ($timeoutMessage.Contains('REGISTERING')) 'WSL registration timeout must be classified distinctly'
    Assert-True ($timeoutMessage.Contains('before Linux packages')) 'WSL failure must not be blamed on NemoClaw'
    Assert-True ($timeoutMessage.Contains('did not impose a 30-second timeout')) 'No false AIW timeout must be claimed'
    Assert-True ($timeoutMessage.Contains('Do not run wsl --shutdown')) 'Do not recommend stopping productive WSL'
    Assert-True ((@(Get-ChildItem -LiteralPath $diag -Filter '*empty-stdin.txt')).Count -eq 0) 'Timeout mock leaked temporary stdin'
    Write-Host '[OK] Observed WSL import: heartbeat, logs, upstream registration timeout diagnosis, no destructive recovery.'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
