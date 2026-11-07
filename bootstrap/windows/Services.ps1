#Requires -Version 7.4
<#
Native Windows AI Workstation workbench.
The interactive UI is task-oriented; direct CLI arguments are forwarded unchanged.
No live service or secret is changed merely by opening a menu.
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
if (-not $uvCmd) { throw 'uv is required for native AI services. See docs/native-host-operations.md.' }

function Invoke-Aiw([string[]]$CommandLine) {
    & $uvCmd.Source run --no-project --with 'PyYAML==6.0.3' python $tool @CommandLine
    if ($LASTEXITCODE -ne 0) {
        throw "AI Workstation action failed (exit $LASTEXITCODE). See the error above."
    }
}

function Confirm-Aiw([string]$Question, [bool]$DefaultYes = $false) {
    $suffix = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $value = (Read-Host "$Question $suffix").Trim()
    if (-not $value) { return $DefaultYes }
    return $value -in @('y', 'Y', 'yes', 'YES')
}

function Get-ServicesFolder {
    if ($env:AIW_SERVICES_DIR) { return [IO.Path]::GetFullPath($env:AIW_SERVICES_DIR) }
    return (Join-Path $env:LOCALAPPDATA 'AIWorkstation\services')
}

function Get-PrivateHostFile {
    Join-Path (Get-ServicesFolder) 'native-host.json'
}

function Open-LocalFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: $Path. Run first-time setup first."
    }
    Write-Host "Opening local file: $Path"
    Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $Path + '"')
}

function Get-ClientRegistry {
    $raw = (& $uvCmd.Source run --no-project --with 'PyYAML==6.0.3' python $tool client list --format json) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read application keys. Run first-time setup.' }
    return ConvertFrom-Json -InputObject $raw -Depth 5
}

function Select-Client([string]$Purpose, [bool]$ForCopy = $false) {
    $list = @((Get-ClientRegistry).clients)
    if ($list.Count -eq 0) {
        Write-Host 'No registered applications yet. Choose Create a new application key.'
        return $null
    }
    Write-Host ''
    Write-Host "Choose the application key to $Purpose (number only):"
    for ($i=0; $i -lt $list.Count; $i++) {
        $origin = switch ($list[$i].origin) {
            'generated' { 'individual key' }
            'imported' { 'legacy shared key' }
            default { 'origin not recorded' }
        }
        Write-Host (' {0,2}  {1} | policy: {2} | {3}' -f ($i+1), $list[$i].id, $list[$i].policy, $origin)
    }
    Write-Host '  0  Cancel'
    $input = (Read-Host 'Application number').Trim()
    $index = 0
    if (-not [int]::TryParse($input, [ref]$index) -or $index -lt 1 -or $index -gt $list.Count) {
        Write-Host 'Selection cancelled.'
        return $null
    }
    $entry = $list[$index-1]
    if ($ForCopy -and $entry.origin -eq 'imported') {
        Write-Warning 'This is an imported shared gateway key; do not provision a new application with it.'
        return $null
    }
    if ($ForCopy -and $entry.origin -ne 'generated') {
        if (-not (Confirm-Aiw 'Confirm this credential is not shared by other applications?')) { return $null }
    }
    return [string]$entry.id
}

function Show-MainMenu {
    Write-Host ''
    Write-Host '=== AI Workstation | Windows inference host ==='
    Write-Host 'Choose what you want to do:'
    Write-Host '  1  Run and monitor AI services'
    Write-Host '     Start, stop, inspect service status or open live logs.'
    Write-Host '  2  Set up or change this computer'
    Write-Host '     Edit native service start settings and check them safely.'
    Write-Host '  3  Manage application access keys'
    Write-Host '     Separate keys for Goose, Open WebUI and other clients.'
    Write-Host '  4  Help and explanations'
    Write-Host '  ?  Show this menu again        q  Exit'
    Write-Host 'No service is started by opening this workbench.'
}

function Show-RunMenu {
    Write-Host ''
    Write-Host '--- Run and monitor AI services ---'
    Write-Host '  1  Start all enabled services'
    Write-Host '     Optionally open the live status and logs monitor.'
    Write-Host '  2  Show current status of managed services'
    Write-Host '  3  Read saved service logs (also after a failed start)'
    Write-Host '  4  Open live service monitor (full-screen; close to return)'
    Write-Host '  5  Stop all AIW-managed services'
    Write-Host '  6  Restart one managed service'
    Write-Host '  0  Back to main menu          ?  Show these options'
}

function Show-SetupMenu {
    Write-Host ''
    Write-Host '--- Set up or change this Windows computer ---'
    Write-Host '  1  First-time preparation'
    Write-Host '     Create private settings, install Process Compose if needed.'
    Write-Host '  2  View service configuration summary'
    Write-Host '     Which programs are configured, enabled and expected to respond?'
    Write-Host '  3  Edit service startup settings'
    Write-Host '     Open native-host.json: programs, arguments, ports and health.'
    Write-Host '  4  Check the edited settings (without starting services)'
    Write-Host '  5  Apply edited settings for the next startup'
    Write-Host '     Generate the managed process definition, then validate it.'
    Write-Host '  6  Check whether old services still occupy the ports'
    Write-Host '  7  Show the private file locations'
    Write-Host '  8  Install official Process Compose (smoke tests only; not approved for live host)'
    Write-Host '  9  Open the step-by-step setup guide'
    Write-Host ' 10  Install the independently reviewed Windows supervisor (pilot)'
    Write-Host '     Requires the matching GitHub Actions artifact ZIP; the old binary stays intact.'
    Write-Host ' 11  Show reviewed supervisor pilot status'
    Write-Host ' 12  Remove reviewed supervisor pilot (only while stopped)'
    Write-Host '  0  Back to main menu          ?  Show these options'
}

function Show-KeysMenu {
    Write-Host ''
    Write-Host '--- Application access keys ---'
    Write-Host '  1  Create a separate API key for an application'
    Write-Host '  2  List applications (without showing their secrets)'
    Write-Host '  3  Copy an application API key to the clipboard'
    Write-Host '  4  Prepare the Dispatcher key-verification file'
    Write-Host '     Write hashes only; this does not restart the Dispatcher.'
    Write-Host '  5  Import an OLD shared gateway key (migration only)'
    Write-Host '  6  Rename an application identity (keep its key)'
    Write-Host '  7  Remove an application from the registry'
    Write-Host '  8  Change model parameter policy for an existing application'
    Write-Host '  0  Back to main menu          ?  Show these options'
}

function Show-HelpMenu {
    Write-Host ''
    Write-Host '--- Help and explanations ---'
    Write-Host '  1  Explain the four native services and how they connect'
    Write-Host '  2  Explain API keys, client identity and Dispatcher'
    Write-Host '  3  Open the detailed Windows setup / test guide'
    Write-Host '  4  Show the native CLI commands for automation'
    Write-Host '  0  Back to main menu          ?  Show these options'
}

function Start-FirstTimeSetup {
    $folder = Get-ServicesFolder
    Write-Host ''
    Write-Host 'First-time setup: prepare the private Windows service configuration.'
    Write-Host "Private location: $folder"
    Write-Host 'This does NOT start, stop, reconfigure or adopt the existing AI services.'
    if (-not (Confirm-Aiw 'Prepare this computer now?')) { return }
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'services.yaml'))) {
        Invoke-Aiw @('init')
    }
    else { Write-Host '[OK] Workbench settings already exist; preserved.' }
    $hostJson = Get-PrivateHostFile
    if (-not (Test-Path -LiteralPath $hostJson)) {
        Invoke-Aiw @('host', 'init')
    }
    else { Write-Host '[OK] Native host settings already exist; preserved.' }
    $binary = Join-Path $folder 'bin\process-compose.exe'
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
        if (Confirm-Aiw 'Download and checksum-verify the pinned Process Compose executable?') {
            Invoke-Aiw @('install')
        }
    }
    else { Write-Host '[OK] Process Compose already installed; not overwritten.' }
    Write-Host ''
    Write-Host 'Next: edit the four services in native-host.json (menu Setup -> Edit).'
    Write-Host 'Then Check and Apply the configuration. Starting production remains guarded.'
    if (Confirm-Aiw 'Open the private startup settings in Notepad now?') {
        Open-LocalFile $hostJson
    }
}

function Start-EnabledServices {
    Write-Host 'Starts the configured native AI services under one Process Compose supervisor.'
    Write-Host 'If the previous startup script still owns any ports, STOP here and plan a controlled handover.'
    Write-Host 'Only the separately opted-in, exact-checksum Windows pilot may start a real native-host project.'
    if (-not (Confirm-Aiw 'Start all enabled services?')) { return }
    $openMonitor = Confirm-Aiw 'Open the live TUI monitor (status and embedded logs) after starting?' $true
    Invoke-Aiw @('up')
    Write-Host '[OK] AI Workstation supervisor launched. Inspect individual readiness in the monitor.'
    if ($openMonitor) {
        Write-Host 'Opening live monitor. Exit the monitor to return here; exiting it does not stop services.'
        Invoke-Aiw @('tui')
    }
}

function Read-ServiceLogs {
    Write-Host ''
    Write-Host 'Read recent persisted output from:'
    Write-Host '  1  All configured services'
    Write-Host '  2  Strata'
    Write-Host '  3  Llama Dispatcher'
    Write-Host '  4  Caddy'
    Write-Host '  5  Open WebUI (when configured)'
    Write-Host '  0  Cancel'
    $choice = (Read-Host 'Number').Trim()
    $target = switch ($choice) {
        '1' { $null }
        '2' { 'strata' }
        '3' { 'dispatcher' }
        '4' { 'caddy' }
        '5' { 'open-webui' }
        default { return }
    }
    if ($null -eq $target) { Invoke-Aiw @('logs-file') }
    else { Invoke-Aiw @('logs-file', $target) }
}

function Restart-ManagedService {
    Write-Host 'Restart ONE process, using its existing private definition:'
    Write-Host '  1  Strata         2  Dispatcher'
    Write-Host '  3  Caddy          4  Open WebUI'
    Write-Host '  0  Cancel'
    $choice = (Read-Host 'Number').Trim()
    $service = switch ($choice) {
        '1' { 'strata' }
        '2' { 'dispatcher' }
        '3' { 'caddy' }
        '4' { 'open-webui' }
        default { return }
    }
    Write-Warning 'Restarting a dependency can interrupt other running services and clients.'
    if (Confirm-Aiw "Restart '$service' now?") { Invoke-Aiw @('restart', $service) }
}

function Run-Menu {
    Show-RunMenu
    while ($true) {
        $choice = (Read-Host 'Service operation (0=back, ?=options)').Trim()
        if ($choice -eq '0') { return }
        if ($choice -eq '?') { Show-RunMenu; continue }
        Write-Host ''
        Write-Host "--- Service operation $choice ---"
        try {
            switch ($choice) {
                '1' { Start-EnabledServices }
                '2' { Invoke-Aiw @('status') }
                '3' { Read-ServiceLogs }
                '4' {
                    Write-Host 'Attach to the existing supervisor. Leaving the monitor does not stop services.'
                    Invoke-Aiw @('tui')
                }
                '5' {
                    Write-Warning 'This stops all services owned by THIS AI Workstation supervisor.'
                    if (Confirm-Aiw 'Stop the supervised AI services?') { Invoke-Aiw @('down') }
                }
                '6' { Restart-ManagedService }
                default { Write-Warning 'Unknown operation. Enter ? for the list.' }
            }
        }
        catch { Write-Warning $_.Exception.Message }
        Write-Host "--- End of service operation $choice (0=back, ?=options) ---"
    }
}

function Setup-Menu {
    Show-SetupMenu
    while ($true) {
        $choice = (Read-Host 'Setup operation (0=back, ?=options)').Trim()
        if ($choice -eq '0') { return }
        if ($choice -eq '?') { Show-SetupMenu; continue }
        Write-Host ''
        Write-Host "--- Setup operation $choice ---"
        try {
            switch ($choice) {
                '1' { Start-FirstTimeSetup }
                '2' { Invoke-Aiw @('host','inspect') }
                '3' { Open-LocalFile (Get-PrivateHostFile) }
                '4' {
                    Write-Host 'Checking private paths, enabled dependencies and health URLs. No process starts.'
                    Invoke-Aiw @('host','validate')
                }
                '5' {
                    Write-Host 'Converts your private JSON changes into Process Compose configuration.'
                    Write-Host 'This does not start/restart any services; an owned running supervisor blocks changes.'
                    if (Confirm-Aiw 'Prepare updated service settings for the next Start?') {
                        Invoke-Aiw @('host','validate')
                        Invoke-Aiw @('host','render')
                        Invoke-Aiw @('check')
                    }
                }
                '6' {
                    Write-Host 'Listening ports owned by the OLD script will be reported as conflicts.'
                    Write-Host 'This check neither stops processes nor changes settings.'
                    Invoke-Aiw @('host','preflight')
                }
                '7' { Invoke-Aiw @('where') }
                '8' {
                    $bin = Join-Path (Get-ServicesFolder) 'bin\process-compose.exe'
                    if (Test-Path -LiteralPath $bin -PathType Leaf) {
                        Write-Host '[OK] Pinned Process Compose already exists. No overwrite performed.'
                    }
                    elseif (Confirm-Aiw 'Download and checksum-verify Process Compose for this user?') {
                        Invoke-Aiw @('install')
                    }
                }
                '9' { Open-LocalFile (Join-Path $root 'docs\native-host-operations.md') }
                '10' {
                    Write-Host 'This installs the checksum-pinned Windows pilot binary in your private AIW directory.'
                    Write-Host 'It does NOT replace the official binary or start/stop any service.'
                    Write-Host 'Use only the ZIP artifact from the reviewed Windows qualification workflow.'
                    $file = (Read-Host 'Full path to downloaded Process Compose review artifact ZIP (Enter cancels)').Trim()
                    if ($file) {
                        if (Confirm-Aiw 'Opt in to this reviewed pilot for later explicit Start commands?') {
                            Invoke-Aiw @('pilot','install','--archive',$file)
                        }
                    }
                }
                '11' { Invoke-Aiw @('pilot','status') }
                '12' {
                    Write-Warning 'Pilot removal is only allowed after its owned supervisor has stopped.'
                    if (Confirm-Aiw 'Remove reviewed pilot registration and binary?') {
                        Invoke-Aiw @('pilot','remove')
                    }
                }
                default { Write-Warning 'Unknown operation. Enter ? for the list.' }
            }
        }
        catch { Write-Warning $_.Exception.Message }
        Write-Host "--- End of setup operation $choice (0=back, ?=options) ---"
    }
}

function Change-ClientPolicy {
    Write-Host 'default: apply role defaults; client-requested values take priority.'
    Write-Host 'enforce: role policy takes priority over client-requested values.'
    Write-Host 'passthrough: forward client parameters; do not inject role defaults.'
    $entry = Select-Client 'change the request policy for'
    if (-not $entry) { return }
    $old = [string]$entry.policy
    $new = (Read-Host 'New policy [default/enforce/passthrough] (Enter cancels)').Trim().ToLowerInvariant()
    if (-not $new) { return }
    if ($new -notin @('default', 'enforce', 'passthrough')) {
        Write-Warning 'Invalid policy. Choose default, enforce or passthrough.'
        return
    }
    if ($new -eq $old) {
        Write-Host "Policy already '$old' for '$($entry.id)'; nothing changed."
        return
    }
    if (Confirm-Aiw "Change '$($entry.id)' policy from '$old' to '$new'?") {
        Invoke-Aiw @('client', 'set-policy', [string]$entry.id, '--policy', $new)
        Write-Host 'Next: after editing all clients, choose option [4] to regenerate the Dispatcher registry.'
        Write-Host 'Then explicitly restart ONLY Dispatcher to activate the new policies.'
    }
}

function Keys-Menu {
    Show-KeysMenu
    while ($true) {
        $choice = (Read-Host 'Access keys operation (0=back, ?=options)').Trim()
        if ($choice -eq '0') { return }
        if ($choice -eq '?') { Show-KeysMenu; continue }
        Write-Host ''
        Write-Host "--- Application key operation $choice ---"
        try {
            switch ($choice) {
                '1' {
                    Write-Host 'Choose an ID identifying ONE application, e.g. goose-wsl or webui-host.'
                    $name = (Read-Host 'New application ID (Enter cancels)').Trim()
                    if ($name -match '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$') {
                        Invoke-Aiw @('client','add',$name,'--policy','passthrough')
                        Write-Host 'The ORIGINAL key was stored encrypted. You can copy it separately (option 3).'
                        Write-Host 'To update the digest registry later, use option 4.'
                    }
                    elseif ($name) { Write-Warning 'Use letters, digits, dot, hyphen or underscore.' }
                }
                '2' { Invoke-Aiw @('client','list') }
                '3' {
                    $name = Select-Client 'copy' $true
                    if ($name) {
                        Write-Host 'Windows clipboard history/sync may retain secrets. Prefer a password manager.'
                        if (Confirm-Aiw "Copy the original key for '$name' to clipboard?") {
                            Invoke-Aiw @('client','copy',$name)
                        }
                    }
                }
                '4' {
                    Write-Host 'Writes the Dispatcher clients.json with one-way SHA-256 key hashes.'
                    Write-Host 'This is NOT the API key to paste into Open WebUI and does not restart a service.'
                    if (Confirm-Aiw 'Regenerate the Dispatcher client key registry?') {
                        Invoke-Aiw @('client','render')
                    }
                }
                '5' {
                    Write-Warning 'Import the EXISTING shared gateway key for a controlled migration only.'
                    Write-Host 'Do not distribute a shared key to new applications.'
                    $name = (Read-Host 'Legacy client ID (Enter cancels)').Trim()
                    if ($name) {
                        $file = (Read-Host 'Full path to existing Windows DPAPI encrypted key').Trim()
                        if ($file -and (Confirm-Aiw "Import shared key under '$name'?")) {
                            Invoke-Aiw @('client','import-dpapi',$name,'--policy','passthrough','--from-file',$file)
                        }
                    }
                }
                '6' {
                    $name = Select-Client 'rename'
                    if ($name) {
                        $next = (Read-Host "New application ID for '$name' (Enter cancels)").Trim()
                        if ($next) { Invoke-Aiw @('client','rename',$name,$next) }
                    }
                }
                '7' {
                    $name = Select-Client 'remove from registration'
                    if ($name) {
                        Write-Warning 'Removes the application from the registry. The original encrypted key is retained for rollback.'
                        Write-Host 'This does not update Dispatcher clients.json until you choose option 4.'
                        if (Confirm-Aiw "Remove registration for '$name'?") {
                            Invoke-Aiw @('client','remove',$name)
                        }
                    }
                }
                '8' { Change-ClientPolicy }
                default { Write-Warning 'Unknown operation. Enter ? for the list.' }
            }
        }
        catch { Write-Warning $_.Exception.Message }
        Write-Host "--- End of application key operation $choice (0=back, ?=options) ---"
    }
}

function Help-Menu {
    Show-HelpMenu
    while ($true) {
        $choice = (Read-Host 'Help topic (0=back, ?=options)').Trim()
        if ($choice -eq '0') { return }
        if ($choice -eq '?') { Show-HelpMenu; continue }
        Write-Host ''
        try {
            switch ($choice) {
                '1' {
                    Write-Host 'Strata: local model inference, usually on the host loopback port 8080.'
                    Write-Host 'Dispatcher: attaches to Strata, exposes model aliases and attributes client requests.'
                    Write-Host 'Caddy: HTTPS entry point, public authentication rules and reverse proxy.'
                    Write-Host 'Open WebUI: browser-based chat app, keeps its existing user database.'
                    Write-Host 'Startup order: Strata -> Dispatcher -> Caddy -> Open WebUI.'
                    Write-Host 'Process Compose: starts/monitors processes; it does not install their models.'
                }
                '2' {
                    Write-Host 'Application client ID: your label for ONE app, not a human WebUI login.'
                    Write-Host 'Original API key: goes into the application connection and stays secret.'
                    Write-Host 'Dispatcher digest registry: hashed original keys, never copy hashes to clients.'
                    Write-Host 'Legacy shared key: preserves old access during migration; not per-app identity.'
                    Write-Host 'Access key registration is separate from an approved live gateway change.'
                }
                '3' { Open-LocalFile (Join-Path $root 'docs\native-host-operations.md') }
                '4' {
                    Write-Host 'Direct native CLI (no interactive menus):'
                    Write-Host '  aiw host inspect             # summary of configured services'
                    Write-Host '  aiw host validate            # check JSON without starting'
                    Write-Host '  aiw host render              # apply edited file while stopped'
                    Write-Host '  aiw check                    # supervisor config dry-run'
                    Write-Host '  aiw up / status / logs-file / tui / down'
                    Write-Host '  aiw client list / add / copy / render'
                    Write-Host '  aiw command-status / unregister  # Windows command registration'
                }
                default { Write-Warning 'Unknown help topic. Enter ? for the list.' }
            }
        }
        catch { Write-Warning $_.Exception.Message }
        Write-Host "--- End of help topic $choice (0=back, ?=options) ---"
    }
}

# Direct non-menu CLI, including legacy commands, remains stable.
if ($Arguments -and $Arguments.Count -gt 0) {
    Invoke-Aiw $Arguments
    return
}

Show-MainMenu
while ($true) {
    $choice = (Read-Host 'Choose task (1-4, ?=options, q=exit)').Trim()
    if ($choice -eq 'q') { break }
    if ($choice -eq '?') { Show-MainMenu; continue }
    switch ($choice) {
        '1' { Run-Menu; Show-MainMenu }
        '2' { Setup-Menu; Show-MainMenu }
        '3' { Keys-Menu; Show-MainMenu }
        '4' { Help-Menu; Show-MainMenu }
        default { Write-Warning 'Unknown task. Enter ? for the list.' }
    }
}
