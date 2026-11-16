#requires -Version 7.4
# Pure parser/guard for the WSL engine, not the Ubuntu distribution version.
# Microsoft's distro-cgroup isolation fix entered WSL 2.9.8; 2.9.13 adds
# the distro-cgroup namespace fix. Do not edit global WSL settings.
function Get-AiwNemoWslEngineVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$VersionOutput)
    foreach ($line in $VersionOutput) {
        $text = ([string]$line -replace [char]0, '').Trim()
        if ($text -match '^WSL(?:\s+|-)?Version\s*:\s*(?<v>\d+\.\d+\.\d+(?:\.\d+)?)') {
            try {
                return [version]$Matches.v
            }
            catch {
                break
            }
        }
    }
    throw 'Cannot parse the WSL engine version. Run wsl.exe --version to inspect it manually. No WSL update or install was performed.'
}

function Assert-AiwNemoWslEngineReady {
    [CmdletBinding()]
    param([Parameter(Mandatory)][version]$InstalledVersion)
    $minimum = [version]'2.9.13'
    if ($InstalledVersion -lt $minimum) {
        throw "WSL version $InstalledVersion predates the Microsoft multi-distro systemd/cgroup fixes (minimum $minimum). Rootless Podman cannot be safely qualified in this setup. No global WSL update was initiated. After reviewing the impact on your other running WSL distributions, update the official Microsoft WSL installation and rerun this same AIW installer. See https://github.com/microsoft/WSL/releases/tag/2.9.13"
    }
}
