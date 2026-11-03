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
    if ($name -ne 'source' -and $name -notmatch '^source-[0-9a-f]{32}
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
            # Inspect before removing: a nested junction/symlink is not owned.
            # An AV lock during enumeration is retryable just like a delete lock.
            $pending = [Collections.Generic.Stack[string]]::new()
            $pending.Push($candidate)
            while ($pending.Count -gt 0) {
                $directory = $pending.Pop()
                foreach ($child in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
                    if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                        throw [InvalidOperationException]::new(
                            "Refusing to clean staging tree with a reparse point: $($child.FullName)"
                        )
                    }
                    if ($child.PSIsContainer) { $pending.Push($child.FullName) }
                }
            }
            Remove-Item -LiteralPath $candidate -Recurse -Force -ErrorAction Stop
        }
        catch {
            if ($_.Exception -is [InvalidOperationException]) { throw }
            # A partly removed *disposable* stage is never reused. The caller
            # selects a new unique location if Windows keeps this one locked.
            if (-not (Test-Path -LiteralPath $candidate)) { return $true }
        }
    }
    return -not (Test-Path -LiteralPath $candidate)
}
) {
        throw "Refusing to clean a non-staging directory: $candidate"
    }
    # Only a *direct child* is AI Workstation-owned staging. A matching
    # basename deeper under logs/, downloads/ or another folder is not ours.
    $parent = [IO.Path]::GetDirectoryName($candidate)
    if (-not [string]::Equals($parent, $root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean nested or foreign staging path: $candidate"
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
