#Requires -Version 7.4
<#
.SYNOPSIS
Native Windows entrypoint to the SAME Process Compose project and S02 identity
management as "aiw services" on WSL/Linux. No WSL requirement on Speedy.
.EXAMPLE
  ./bootstrap/windows/Services.ps1
  ./bootstrap/windows/Services.ps1 client add goose-laptop --policy passthrough
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$tool = Join-Path $root 'tools/aiw-services.py'
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uvCmd) { throw 'uv not on PATH; use the Python/uv installation already used for Dispatcher.' }

function Invoke-NativeServices([string[]]$Commands) {
    # Native Windows dependency isolation; never installs Linux Ansible packages.
    & $uvCmd.Source run --no-project --with 'PyYAML==6.0.3' python $tool @Commands
    if ($LASTEXITCODE -ne 0) {
        throw "AI Workstation native services failed with exit code $LASTEXITCODE."
    }
}

if ($Arguments -and $Arguments.Count -gt 0) {
    Invoke-NativeServices $Arguments
    return
}

while ($true) {
    Write-Host ''
    Write-Host 'AI Workstation - native Windows services (Process Compose)'
    Write-Host '1  Configuration paths'
    Write-Host '2  Initialize PRIVATE YAML and disabled smoke service'
    Write-Host '3  Install checksum-verified Process Compose'
    Write-Host '4  Validate Process Compose YAML (no start)'
    Write-Host '5  Process status'
    Write-Host '6  Native Process Compose TUI'
    Write-Host '7  Start project (explicit)'
    Write-Host '8  Stop project'
    Write-Host '9  Logs'
    Write-Host '10 Create named Dispatcher client'
    Write-Host '11 List clients'
    Write-Host '12 Render Dispatcher S02 client JSON'
    Write-Host '13 Import existing gateway DPAPI key (keep current clients working)'
    Write-Host 'q  Exit'
    $choice = Read-Host 'Select'
    $command = switch ($choice) {
        '1'  { @('where') }
        '2'  { @('init') }
        '3'  { @('install') }
        '4'  { @('check') }
        '5'  { @('status') }
        '6'  { @('tui') }
        '7'  { @('up') }
        '8'  { @('down') }
        '9'  { @('logs') }
        '10' {
            $name = Read-Host 'Client ID (goose-laptop, webui-speedy, hermes-speedy)'
            if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$') {
                Write-Warning 'Invalid client ID.'
                @()
            }
            else {
                @('client', 'add', $name, '--policy', 'passthrough')
            }
        }
        '11' { @('client', 'list') }
        '12' { @('client', 'render') }
        '13' {
            $path = Read-Host 'Existing gateway DPAPI file (e.g. C:\Caddy\speedy-api-key.dpapi)'
            if (-not $path) { @() }
            else { @('client', 'import-dpapi', 'home-gateway', '--policy', 'passthrough', '--from-file', $path) }
        }
        'q' { return }
        'Q' { return }
        default { Write-Warning 'Unknown choice.'; @() }
    }
    if (-not $command -or $command.Count -eq 0) { continue }
    if ($choice -in @('7','8')) {
        $answer = Read-Host "Execute '$($command -join ' ')' now? [y/N]"
        if ($answer -ne 'y' -and $answer -ne 'Y') { continue }
    }
    try { Invoke-NativeServices $command }
    catch { Write-Warning $_.Exception.Message }
}
