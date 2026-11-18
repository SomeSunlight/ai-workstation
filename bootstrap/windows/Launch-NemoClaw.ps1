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
if ($LASTEXITCODE -ne 0 -or ($marker -join '').Trim() -cne 'nemoclaw-podman') {
    throw "WSL '$DistroName' is missing or is not an AIW NemoClaw installation. No command was started."
}
$workdir = "/home/$LinuxUser/ai-workstation"
# Report the *Linux* checkout actually being executed, not the Windows source
# revision used to refresh the shortcut. The two projects will split (#78).
# Purely local Git reads: no fetch, pull, installer or sandbox mutation.
$identityProbe = @'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sha="$(git rev-parse --short=7 HEAD)"
  ref="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf detached)"
  dirty=''
  if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then dirty=', dirty'; fi
  printf '%s@%s%s\n' "$ref" "$sha" "$dirty"
else
  printf 'unknown (no Git checkout)\n'
fi
'@
$linuxIdentity = @(& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /bin/bash -lc $identityProbe 2>&1)
if ($LASTEXITCODE -eq 0 -and $linuxIdentity.Count -gt 0) {
    Write-Host "Linux workbench code: $(($linuxIdentity -join ' ').Trim())"
}
else {
    Write-Warning 'Linux workbench Git identity could not be read; proceeding without updates.'
}
& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /bin/bash -lc 'bash ./bin/aiw-nemo'
if ($LASTEXITCODE -ne 0) {
    throw "NemoClaw menu exited with error $LASTEXITCODE. Inspect the messages above."
}
Write-Host 'The NemoClaw menu closed. The PowerShell window stays open.'
