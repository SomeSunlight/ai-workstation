#requires -Version 7.4
# Bounded best-effort cleanup of AI Workstation-owned installer staging only.
# Never recursively traverse a junction or symlink, or touch user-owned data.

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
    # Only direct children of the managed root belong to this stage lifecycle.
    $parent = [IO.Path]::GetDirectoryName($candidate)
    if (-not [string]::Equals($parent, $root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a nested or foreign staging path: $candidate"
    }

    foreach ($delay in $RetryDelaysMs) {
        if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
        if (-not (Test-Path -LiteralPath $candidate)) { return $true }

        try {
            $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [InvalidOperationException]::new("Refusing staging reparse point: $candidate")
            }
            if (-not $item.PSIsContainer) {
                throw [InvalidOperationException]::new("Staging root is not a directory: $candidate")
            }

            # Enumerate every descendant before recursive deletion. A transient
            # scanner lock during enumeration is treated like a delete lock.
            $pending = [Collections.Generic.Stack[string]]::new()
            $pending.Push($candidate)
            while ($pending.Count -gt 0) {
                $directory = $pending.Pop()
                foreach ($child in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
                    if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                        throw [InvalidOperationException]::new(
                            "Refusing staging tree with reparse point: $($child.FullName)"
                        )
                    }
                    if ($child.PSIsContainer) { $pending.Push($child.FullName) }
                }
            }

            Remove-Item -LiteralPath $candidate -Recurse -Force -ErrorAction Stop
            return $true
        }
        catch {
            if ($_.Exception -is [InvalidOperationException]) { throw }
            # The old disposable stage may now be only partially removed.
            # Never reuse it: the caller allocates a new unique stage if locked.
            if (-not (Test-Path -LiteralPath $candidate)) { return $true }
        }
    }
    return -not (Test-Path -LiteralPath $candidate)
}
