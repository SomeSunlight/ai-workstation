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
    Write-Host '10 Create client identity (you choose the name; generates protected key)'
    Write-Host '11 List client identities and policies (NO secrets)'
    Write-Host '12 Generate Dispatcher client JSON (HASHES only; NOT a key backup)'
    Write-Host '13 Import existing gateway DPAPI key (keep current clients working)'
    Write-Host '14 Copy one ORIGINAL client key to clipboard for KeePass'
    Write-Host '15 Explain identities, secrets, hashes, KeePass'
    Write-Host '16 Rename a client ID without changing its key'
    Write-Host 'q  Exit'
    $choice = Read-Host 'Select'
    if ($choice -in @('q', 'Q')) { break }
    # A PowerShell switch unrolls its output: a single command becomes a
    # scalar string. Force a real argv array so .Count and argument passing
    # remain stable under Set-StrictMode.
    $command = @(switch ($choice) {
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
            Write-Host ''
            Write-Host 'Choose ANY unique client ID for one application/provider connection.'
            Write-Host 'For example: goose-research, webui-private, hermes-automation.'
            Write-Host 'These are EXAMPLES, not preconfigured names. Do not use a device name unless you want to.'
            Write-Host 'A new API key is generated and stored under your Windows account (DPAPI).'
            Write-Host 'Copy the key to KeePass later using menu 14.'
            $name = Read-Host 'Your new client ID'
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
        '14' {
            Write-Host 'Copy an ORIGINAL API key into the clipboard for KeePass.'
            Write-Host 'WARNING: Clipboard history/sync can retain this sensitive key.'
            Write-Host 'Paste into a KeePass Password field and clear clipboard/history afterward.'
            $id = Read-Host 'Existing client ID'
            if (-not $id) { @() }
            else {
                $confirm = Read-Host 'Copy sensitive original key to clipboard? [y/N]'
                if ($confirm -in @('y','Y')) { @('client', 'copy', $id) }
                else { @() }
            }
        }
        '15' {
            Write-Host ''
            Write-Host 'A CLIENT is one application/provider connection, not a computer or person.'
            Write-Host 'Client IDs are labels YOU choose. Examples are suggestions only.'
            Write-Host 'services.yaml = names and policies; process-compose.yaml = native processes.'
            Write-Host 'secrets/*.dpapi = actual API keys encrypted for this Windows user.'
            Write-Host 'clients.json = ONE-WAY HASHES, read by Dispatcher to authenticate requests.'
            Write-Host 'IMPORTANT: clients.json is NOT a backup of your usable API keys.'
            Write-Host 'KeePass: choose menu 14 for EACH key and paste it into an entry Password field.'
            Write-Host 'Never copy your entire secrets folder as a portable credential backup.'
            Write-Host 'Client changes DO NOT alter the running Dispatcher/Caddy automatically.'
            @()
        }
        '16' {
            Write-Host 'Rename client identity. Its protected API key remains unchanged.'
            $oldId = Read-Host 'Existing client ID'
            $newId = Read-Host 'New unique client ID'
            if (-not $oldId -or -not $newId) { @() }
            else { @('client', 'rename', $oldId, $newId) }
        }
        default { Write-Warning 'Unknown choice.'; @() }
    })
    if ($command.Count -eq 0) { continue }
    if ($choice -in @('7','8')) {
        $answer = Read-Host "Execute '$($command -join ' ')' now? [y/N]"
        if ($answer -ne 'y' -and $answer -ne 'Y') { continue }
    }
    try { Invoke-NativeServices $command }
    catch { Write-Warning $_.Exception.Message }
}
