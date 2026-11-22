#requires -Version 7.4
# Offline safety contract only: no WSL, Windows setup, downloads or Git network.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry = Get-Content -LiteralPath (Join-Path $root 'install-linux-workstation.ps1') -Raw
$public = Get-Content -LiteralPath (Join-Path $root 'install-nemoclaw.ps1') -Raw
$elevated = Get-Content -LiteralPath (Join-Path $root 'install.ps1') -Raw
$engine = Get-Content -LiteralPath (Join-Path $root 'bootstrap/windows/Install-AiWorkstation.ps1') -Raw
$pin = Get-Content -LiteralPath (Join-Path $root 'config/linux-project.json') -Raw | ConvertFrom-Json
function Require([bool]$ok, [string]$message) {
    if (-not $ok) { throw $message }
}
Require ($pin.commit -ceq '7c858a6daac83af01bed727c6c4c437f5f5d81f5') 'Candidate must be corrected Linux Draft PR #7 commit'
Require ($pin.resumeFromCommit -ceq '6dc45a81d8f5a305ec9f159584db3e181df83985') 'Only the exact prior installer candidate can resume'
Require ($entry.Contains("DistroName = 'AIW-Nemo-New'")) 'Fresh distro default missing'
Require ($entry.Contains('-IndependentLinuxProject')) 'New entrypoint does not select pinned Linux'
Require ($public.Contains('IndependentLinuxProject = $IndependentLinuxProject')) 'Nemo wrapper did not forward mode'
Require ($elevated.Contains('[switch]$IndependentLinuxProject')) 'Elevation/resume entrypoint drops install mode'
Require ($engine.Contains('if ($IndependentLinuxProject -and $Action -eq ''Install'')')) 'Early pre-mutation guard absent'
Require ($engine.Contains('if ($DistroName -in @(''Ubuntu-24.04'',''Ubuntu-26.04'',''AIW-Nemo''))')) 'Protected distro name guard absent'
Require ($engine.Contains('/etc/aiw-linux-project-install')) 'Foreign existing WSL marker rejection absent'
Require ($engine.Contains('Assert-IndependentLinuxGuestRelease')) 'Guest Ubuntu version preflight absent'
Require ($engine.Contains('26[.]04')) 'Guest Ubuntu 26.04 required version missing'
Require ($engine.Contains('git clone "$url" "$path"')) 'Independent checkout not cloned from pinned authority'
Require ($engine.Contains('git -C "$path" checkout --detach "$commit"')) 'Immutable checked-out commit missing'
Require ($engine.Contains('Linux source revision differs from immutable pin')) 'Wrong-pin refusal absent'
Require ($engine.Contains('git -C "$path" fetch --no-tags origin "$commit"')) 'Explicit, pinned Git fetch for interrupted install is missing'
Require ($engine.Contains('"$current" == "$resume_from"')) 'Automatic upgrade of unreviewed checkouts must be refused'
Require ($engine.Contains('Linux checkout is dirty; no update attempted')) 'Dirty source migration is not refused'
Require ($engine.Contains('Existing NemoClaw install receipt found')) 'Already installed NemoClaw is not detected for resume'
Require ($engine.Contains("'./install.sh', 'register-cli'")) 'Missing idempotent CLI finish without reinstall'
Require ($engine.Contains('No automatic reinstall or upgrade performed')) 'Failed verification must not trigger installer mutations'
Require ($engine.Contains("'./install.sh', 'install'")) 'Linux-owned install command not delegated'
Require ($engine.Contains("Invoke-LinuxWorkstation.ps1') -Action Verify")) 'Linux read-only verifier not called after installation'
Require ($engine.Contains('if (-not $IndependentLinuxProject) { Ensure-WindowsShortcuts }')) 'Shortcut order must preserve original legacy path'
Require ($engine.Contains('if ($IndependentLinuxProject) { Ensure-WindowsShortcuts }')) 'New shortcut creation must follow successful installer'
Require (-not $entry.Contains('wsl --unregister')) 'Entrypoint must not unregister WSL'
Require ($engine.Contains('Preserving global .wslconfig')) 'Global WSL configuration must be preserved'
# Execute just the no-side-effect WSL helper in isolation, with a PowerShell
# mock (never call native wsl.exe in this regression).
$functionMatch = [regex]::Match($engine, '(?ms)^function Invoke-Wsl \{\r?\n.*?^\}')
Require ($functionMatch.Success) 'WSL helper not found for direct exit-code regression'
Invoke-Expression $functionMatch.Value
$script:MockWslExitCode = 0
function wsl.exe {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$NativeArgs)
    Write-Output 'Linux verifier says: success'
    $global:LASTEXITCODE = $script:MockWslExitCode
}
$result = @(Invoke-Wsl -AllowFailure -Arguments @('--offline-mock'))
Require ($result.Count -eq 1) 'Linux stdout polluted scalar WSL return value'
Require ($result[0] -is [int] -and $result[0] -eq 0) 'Successful WSL stdout falsely flagged as failed'
$script:MockWslExitCode = 17
$result = @(Invoke-Wsl -AllowFailure -Arguments @('--offline-mock'))
Require ($result.Count -eq 1 -and $result[0] -is [int] -and $result[0] -eq 17) 'Failed WSL returned something other than its exit code'
$threw = $false
try {
    Invoke-Wsl -Arguments @('--offline-mock')
}
catch {
    $threw = $_.Exception.Message.Contains('exit code 17')
}
Require $threw 'Failed WSL command without AllowFailure was not rejected'
Remove-Item Function:wsl.exe -ErrorAction SilentlyContinue
# The mock intentionally set the session-native exit code to 17. Reset the
# test harness state so pwsh does not itself finish with the mocked failure.
$global:LASTEXITCODE = 0
Write-Host '[OK] Mocked WSL: native stdout visible, only numeric exit code returned; real failure rejected.'

Write-Host '[OK] Windows fresh WSL installer: isolated target, immutable Linux handoff, verified install, no destructive operations.'
