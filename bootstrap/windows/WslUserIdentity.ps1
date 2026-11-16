#requires -Version 7.4
# Pure WSL identity validation. A warning on stderr is NOT the username.
function Assert-AiwWslDefaultUserIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$StandardOutput,
        [Parameter(Mandatory)][string]$ExpectedUser,
        [Parameter(Mandatory)][string]$DistroName,
        [Parameter(Mandatory)][int]$ExitCode
    )
    if ($ExitCode -ne 0) {
        throw "WSL failed to check the default user for '$DistroName' (exit code $ExitCode)."
    }
    $lines = @($StandardOutput |
        ForEach-Object { ([string]$_ -replace [char]0, '').Trim() } |
        Where-Object { $_.Length -gt 0 })
    if ($lines.Count -ne 1) {
        throw "WSL returned $($lines.Count) nonempty stdout lines when querying the default user of '$DistroName' (expected exactly one)."
    }
    if ($lines[0] -cne $ExpectedUser) {
        throw "Expected default Linux user '$ExpectedUser' in '$DistroName', found '$($lines[0])'."
    }
}
