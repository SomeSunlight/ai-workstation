#requires -Version 7.4
# Launch only the explicitly named NemoClaw WSL distribution.
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName = 'AIW-Nemo',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser = 'moresunlight',
    [ValidateSet('Workbench','Home')]
    [string]$Mode = 'Workbench',
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
$workdir = if ($Mode -eq 'Home') { "/home/$LinuxUser" } else { "/home/$LinuxUser/ai-workstation-linux" }
# Show the checkout identity only for the project shortcut. It is a separate
# Linux working tree; refreshing a Windows icon does not update Linux code.
if ($Mode -eq 'Workbench') {
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
        Write-Warning 'Linux Git revision could not be checked; no automatic update was attempted.'
    }
}
Write-Host "Starting interactive Linux shell: $DistroName ($Mode)"
Write-Host "Linux directory: $workdir"
Write-Host 'Start the AIW menu when YOU choose by typing: aiw'
Write-Host 'To leave the Linux shell, type: exit (the window then closes).'
# Deliberately enter a *real interactive Linux login shell*.
# Do not start AIW automatically: q/Enter returns to Linux, not Windows.
& $WslExecutable --distribution $DistroName --user $LinuxUser --cd $workdir --exec /bin/bash -il
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Linux session failed with exit code $LASTEXITCODE. No sandbox was modified."
    Write-Host "Manual start: wsl -d $DistroName -u $LinuxUser --cd ~"
    Read-Host 'Press Enter to close this window' | Out-Null
}
