#requires -Version 7.4
# Shared, bounded best-effort cleanup of AI Workstation-owned installer staging.
# Other project directories and authoritative data must never be deleted here.

function Remove-AiwOwnedStagingTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$StateRoot,
        [int[]]$RetryDelaysMs = @(0, 50, 150, 350)
    )

    $root = [IO.Path]::GetFullPath($StateRoot).TrimEnd('\', '/')
    $candidate = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean outside AI Workstation state root: $candidate"
    }
    $name = [IO.Path]::GetFileName($candidate)
    if ($name -ne 'source' -and $name -notmatch '^source-[0-9a-f]{32}$') {
        throw "Refusing to clean a non-staging directory: $candidate"
    }

    foreach ($delay in $RetryDelaysMs) {
        if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
        if (-not (Test-Path -LiteralPath $candidate)) { return $true }

        $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to recurse into staging reparse point: $candidate"
        }
        if (-not $item.PSIsContainer) {
            throw "Staging root is not a directory: $candidate"
        }

        try {
            Remove-Item -LiteralPath $candidate -Recurse -Force -ErrorAction Stop
        }
        catch {
            # A partly removed *disposable* stage is never reused. The caller
            # selects a new unique location if Windows keeps this one locked.
            if (-not (Test-Path -LiteralPath $candidate)) { return $true }
        }
    }
    return -not (Test-Path -LiteralPath $candidate)
}
