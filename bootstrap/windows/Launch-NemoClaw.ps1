#requires -Version 7.4
# Launch only the explicitly named NemoClaw WSL distribution.
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName = 'AIW-Nemo',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser = 'moresunlight',
    [string]$WslExecutable = (Join-Path $env:WINDIR 'System32\wsl.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

Write-Host "NemoClaw + Hermes | WSL: $DistroName"
Write-Host "The existing Ubuntu installations are not started or managed here."
$marker = @(& $WslExecutable --distribution $DistroName --user root --exec /bin/cat /etc/aiw-install-profile 2>&1)
if ($LASTEXITCODE -ne 0 -or ($marker -join '').Trim() -cne 'nemoclaw') {
    throw "WSL '$DistroName' is missing or is not an AIW NemoClaw installation. No command was started."
}
$workdir = "/home/$LinuxUser/ai-workstation"
& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /bin/bash -lc 'bash ./bin/aiw-nemo'
if ($LASTEXITCODE -ne 0) {
    throw "NemoClaw menu exited with error $LASTEXITCODE. Inspect the messages above."
}
Write-Host 'The NemoClaw menu closed. The PowerShell window stays open.'
