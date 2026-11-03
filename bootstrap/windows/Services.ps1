#Requires -Version 7.4
<#
Native Windows entry point for Process Compose and named Dispatcher clients.
Menu remains visible in scrollback; ? redisplays it on demand.
Details: docs/native-services.md in this repository.
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
if (-not $uvCmd) { throw 'uv is required for native services (see setup guide).' }

function Invoke-NativeServices([string[]]$Commands) {
    & $uvCmd.Source run --no-project --with 'PyYAML==6.0.3' python $tool @Commands
    if ($LASTEXITCODE -ne 0) {
        throw "Native services command failed (exit $LASTEXITCODE)."
    }
}

function Get-ClientRegistry {
    # Read-only structured output; no secrets and no need to retype client IDs.
    $json = (& $uvCmd.Source run --no-project --with 'PyYAML==6.0.3' python $tool client list --format json) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read client registry.' }
    return ConvertFrom-Json -InputObject $json -Depth 5
}

function Select-RegisteredClient {
    param([string]$Purpose, [bool]$ForCopy = $false)
    $registry = Get-ClientRegistry
    $clients = @($registry.clients)
    if ($clients.Count -eq 0) {
        Write-Host 'No client identities registered. Choose option 10 to create one.'
        return $null
    }
    Write-Host ''
    Write-Host "Select client to $Purpose (choose NUMBER; no exact spelling required):"
    for ($i = 0; $i -lt $clients.Count; $i++) {
        $origin = $clients[$i].origin
        $tag = switch ($origin) {
            'generated' { 'individual key' }
            'imported' { 'imported shared key / migration' }
            default { 'older key / origin unknown' }
        }
        Write-Host (" {0,2}) {1}   [{2}]" -f ($i + 1), $clients[$i].id, $tag)
    }
    Write-Host '  0) Cancel'
    $value = Read-Host 'Number'
    $index = 0
    if (-not [int]::TryParse($value, [ref]$index) -or $index -lt 1 -or $index -gt $clients.Count) {
        Write-Host 'Selection cancelled (or invalid).'
        return $null
    }
    $entry = $clients[$index - 1]
    if ($ForCopy -and $entry.origin -eq 'imported') {
        Write-Warning 'Imported shared keys are retained for migration, NOT for provisioning additional clients.'
        Write-Host 'Create a new client identity (10) to give an application its own key.'
        return $null
    }
    if ($ForCopy -and $entry.origin -ne 'generated') {
        Write-Warning 'Older registration: this key may be shared with existing services.'
        $approved = Read-Host 'Confirm this is an individual key, NOT a shared gateway credential? [y/N]'
        if ($approved -notin @('y', 'Y')) { return $null }
    }
    return [string]$entry.id
}

function Show-ServicesMenu {
    Write-Host ''
    Write-Host '=== AI Workstation | Native services ==='
    Write-Host '  1  Paths       2  Initialize     3  Install      4  Validate'
    Write-Host '  5  Status      6  TUI            7  Start        8  Stop       9  Logs'
    Write-Host ' 10  Add client 11  Clients       12  Render S02   13  Import key'
    Write-Host ' 14  Copy key   15  Concepts      16  Rename client'
    Write-Host ' 17  Host setup   18  Render host  19  Host preflight'
    Write-Host '  ?   Show menu again           q   Exit'
    Write-Host 'Guide: docs/native-services.md (in this checkout)'
    Write-Host 'Actions remain visible above; the menu is not repeated automatically.'
}

function Show-KeyConcepts {
    Write-Host ''
    Write-Host 'Client ID       Unique label for one application/provider; chosen by you.'
    Write-Host 'Original key    Secret needed by a client; encrypted locally on Windows.'
    Write-Host 'services.yaml   Human-editable IDs and policies (no secrets).'
    Write-Host 'clients.json    One-way key hashes for Dispatcher; NOT a key backup.'
    Write-Host 'Imported key    Existing shared credential retained for migration only.'
    Write-Host 'Password store  Save individual ORIGINAL keys in any trusted password manager.'
    Write-Host 'Full explanation: docs/native-services.md in your repository checkout.'
}

if ($Arguments -and $Arguments.Count -gt 0) {
    Invoke-NativeServices $Arguments
    return
}

Show-ServicesMenu
while ($true) {
    $choice = (Read-Host 'Option (?=menu, q=exit)').Trim()
    if ($choice -eq 'q') { break }
    if ($choice -eq '?') { Show-ServicesMenu; continue }
    Write-Host ''
    Write-Host "--- Action $choice ---"
    $command = @()
    try {
        switch ($choice) {
            '1'  { $command = @('where') }
            '2'  { $command = @('init') }
            '3'  { $command = @('install') }
            '4'  { $command = @('check') }
            '5'  { $command = @('status') }
            '6'  { $command = @('tui') }
            '7'  { $command = @('up') }
            '8'  { $command = @('down') }
            '9'  { $command = @('logs') }
            '10' {
                Write-Host 'A client ID is an arbitrary unique label for an application.'
                Write-Host 'Example: editor-agent. Examples are NOT preconfigured clients.'
                $name = Read-Host 'New client ID (letters/digits/._-; Enter cancels)'
                if ($name -and $name -match '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$') {
                    $command = @('client', 'add', $name, '--policy', 'passthrough')
                } elseif ($name) { Write-Warning 'Invalid client ID.' }
            }
            '11' { $command = @('client', 'list') }
            '12' { $command = @('client', 'render') }
            '13' {
                Write-Host 'Import an existing shared credential to preserve old client access.'
                Write-Host 'This is NOT a new individual key; do not distribute it to new apps.'
                $name = Read-Host 'Existing logical ID (Enter cancels)'
                if ($name) {
                    $path = Read-Host 'Path to existing Windows DPAPI file'
                    if ($path) {
                        $command = @('client', 'import-dpapi', $name, '--policy', 'passthrough', '--from-file', $path)
                    }
                }
            }
            '14' {
                $id = Select-RegisteredClient -Purpose 'copy an original key' -ForCopy $true
                if ($id) {
                    Write-Host 'The clipboard can be logged/synced by Windows. Use a trusted password manager.'
                    $confirm = Read-Host "Copy key for '$id' to clipboard? [y/N]"
                    if ($confirm -in @('y','Y')) { $command = @('client', 'copy', $id) }
                }
            }
            '15' { Show-KeyConcepts }
            '16' {
                $old = Select-RegisteredClient -Purpose 'rename'
                if ($old) {
                    $new = Read-Host "New ID for '$old' (Enter cancels)"
                    if ($new) { $command = @('client', 'rename', $old, $new) }
                }
            }
            '17' { $command = @('host', 'init') }
            '18' {
                Write-Host 'Render three private Windows host service definitions. No process will start.'
                $answer = Read-Host 'Replace AIW-managed native project with rendered definition? [y/N]'
                if ($answer -in @('y', 'Y')) { $command = @('host', 'render') }
            }
            '19' { $command = @('host', 'preflight') }
            default { Write-Warning "Unknown option '$choice'. Press ? to see the menu." }
        }

        if ($command.Count -gt 0) {
            if ($choice -in @('7', '8')) {
                $answer = Read-Host "Execute '$($command -join ' ')' now? [y/N]"
                if ($answer -notin @('y','Y')) { $command = @() }
            }
            if ($command.Count -gt 0) { Invoke-NativeServices $command }
        }
    }
    catch { Write-Warning $_.Exception.Message }
    Write-Host "--- End of action $choice (press ? for menu) ---"
}
