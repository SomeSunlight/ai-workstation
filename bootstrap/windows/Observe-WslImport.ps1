#requires -Version 7.4
# Observe native Windows WSL import without hiding interactive prompts.
# Never delete a WSL distro, timeout-kill or change global WSL settings.
Set-StrictMode -Version Latest

# Pure classification of stable WSL error identifiers. This is diagnostic
# only: no retry, host service restart, distro termination or cleanup.
function Get-AiwWslImportFailureMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [AllowEmptyString()][string]$OutputText = ''
    )
    if ($OutputText.Contains('RegisterDistro/WSAETIMEDOUT')) {
        return @(
            "Microsoft WSL timed out while REGISTERING the new distribution (RegisterDistro/WSAETIMEDOUT; exit code $ExitCode)."
            'The failure occurred in WSL before Linux packages, Podman or NemoClaw could install.'
            'AIW did not impose a 30-second timeout. Do not retry repeatedly or clean an unregistered VHDX automatically.'
            'Read-only diagnostics: wsl --list --verbose; wsl -d Ubuntu-24.04 --exec /bin/true; wsl -d AIW-Nemo --exec /bin/true.'
            'Do not run wsl --shutdown, terminate other WSL distributions, or restart the WSL service automatically.'
            'Preserve the WSL stdout/stderr logs for a later Microsoft WSL diagnostic trace.'
        ) -join ' '
    }
    return "WSL import failed (exit code $ExitCode)."
}

function Invoke-AiwObservedWslImport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogDirectory,
        [Parameter(Mandatory)][string]$InstallLocation,
        [ValidateRange(1,300)][int]$HeartbeatSeconds = 15
    )

    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    $run = ('wsl-import-{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [Guid]::NewGuid().ToString('N').Substring(0,8))
    $stdoutFile = Join-Path $LogDirectory "$run.stdout.log"
    $stderrFile = Join-Path $LogDirectory "$run.stderr.log"
    $emptyInputFile = Join-Path $LogDirectory "$run.empty-stdin.txt"
    [IO.File]::WriteAllText($emptyInputFile, '', [Text.Encoding]::UTF8)

    Write-Host "[..] Starting WSL image import. The child process is observed."
    Write-Host "[..] Standard output: $stdoutFile"
    Write-Host "[..] Error output   : $stderrFile"
    Write-Host '[..] Periodic status will appear even if WSL is silent.'
    Write-Host '[..] WSL import is noninteractive: never press Return blindly.'

    $process = $null
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $previousSizes = @{}
    $longWarningShown = $false
    try {
        # Deliberately connect an empty stdin: WSL --install --from-file
        # must not wait indefinitely for an invisible keyboard prompt.
        $params = @{
            FilePath = $Executable
            ArgumentList = $Arguments
            NoNewWindow = $true
            PassThru = $true
            RedirectStandardInput = $emptyInputFile
            RedirectStandardOutput = $stdoutFile
            RedirectStandardError = $stderrFile
        }
        $process = Start-Process @params
        if ($null -eq $process) {
            throw 'Could not start the WSL import process.'
        }

        while (-not $process.WaitForExit($HeartbeatSeconds * 1000)) {
            $elapsed = $stopwatch.Elapsed.ToString('hh\:mm\:ss')
            $diskInfo = 'no virtual disk detected yet'
            try {
                $images = @(Get-ChildItem -LiteralPath $InstallLocation -Filter '*.vhdx' -File -Recurse -ErrorAction SilentlyContinue)
                if ($images.Count -gt 0) {
                    $total = ($images | Measure-Object -Property Length -Sum).Sum
                    $diskInfo = ('{0:N1} MiB VHDX on disk' -f ($total / 1MB))
                }
            }
            catch {
                $diskInfo = 'virtual disk size not available'
            }
            Write-Host "[..] WSL image import STILL RUNNING: $elapsed elapsed, PID $($process.Id); $diskInfo."

            foreach ($file in @($stdoutFile, $stderrFile)) {
                if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
                $length = (Get-Item -LiteralPath $file).Length
                $previous = if ($previousSizes.ContainsKey($file)) { $previousSizes[$file] } else { 0 }
                if ($length -gt $previous) {
                    foreach ($line in @(Get-Content -LiteralPath $file -Tail 3 -ErrorAction SilentlyContinue)) {
                        Write-Host "[WSL] $line"
                    }
                }
                $previousSizes[$file] = $length
            }

            if (-not $longWarningShown -and $stopwatch.Elapsed.TotalMinutes -ge 5) {
                $longWarningShown = $true
                Write-Host '[!!] Import is taking longer than expected; no percentage or ETA is supplied by WSL.'
                Write-Host '[!!] Inspect the diagnostic files and virtual disk activity.'
                Write-Host '[!!] Never delete a partially imported WSL image while its process is active.'
            }
        }

        $process.WaitForExit()
        $code = $process.ExitCode
        $stopwatch.Stop()
        Write-Host "[..] WSL import process exited after $($stopwatch.Elapsed.ToString('hh\:mm\:ss')) (exit code: $code)."
        foreach ($file in @($stdoutFile, $stderrFile)) {
            if ((Test-Path -LiteralPath $file -PathType Leaf) -and
                ((Get-Item -LiteralPath $file).Length -gt 0)) {
                Write-Host "[..] Last 20 lines from $file"
                Get-Content -LiteralPath $file -Tail 20 | ForEach-Object { Write-Host "[WSL] $_" }
            }
        }
        if ($code -ne 0) {
            $failureText = @(
                foreach ($file in @($stdoutFile, $stderrFile)) {
                    if (Test-Path -LiteralPath $file -PathType Leaf) {
                        Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
                    }
                }
            ) -join "`n"
            $reason = Get-AiwWslImportFailureMessage -ExitCode $code -OutputText $failureText
            throw "$reason See $stdoutFile and $stderrFile. No existing WSL distributions were deleted."
        }
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
        Remove-Item -LiteralPath $emptyInputFile -ErrorAction SilentlyContinue
    }
}
