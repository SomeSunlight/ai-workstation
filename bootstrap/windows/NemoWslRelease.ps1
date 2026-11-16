#requires -Version 7.4
# Pure parser for WSL /etc/os-release output. No WSL or filesystem mutation.
function Get-AiwNemoUbuntuVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Lines)
    $values = @{}
    foreach ($rawLine in $Lines) {
        $line = ([string]$rawLine -replace "`0", '').Trim()
        if ($line -match '^(ID|VERSION_ID)=(.*)$') {
            $value = $Matches[2].Trim().Trim('"').Trim("'")
            $values[$Matches[1]] = $value
        }
    }
    if ($values['ID'] -cne 'ubuntu') {
        throw "Expected Ubuntu, found ID='$($values['ID'])'. Refusing deletion."
    }
    $release = [string]$values['VERSION_ID']
    if ($release -notin @('24.04', '26.04')) {
        throw "Unexpected Ubuntu VERSION_ID='$release'. Only known NemoClaw experiments 24.04/26.04 can be removed."
    }
    return $release
}
