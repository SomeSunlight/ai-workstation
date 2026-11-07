#Requires -Version 7.4
<#
.SYNOPSIS
    Isolated Windows child-tree qualification for Process Compose.
.DESCRIPTION
    Starts a disposable supervisor -> PowerShell parent -> PowerShell TCP child.
    Asserts that 'down' kills both descendants and frees the child port.
    CI runner only. Never reads user config or touches live host services.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Binary)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $env:RUNNER_TEMP) { throw 'Disposable CI runner required.' }
if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) { throw 'Missing supervisor binary.' }
$folder = Join-Path $env:RUNNER_TEMP ("aiw-pc-tree-O'Brien space-" + [guid]::NewGuid().ToString('N'))
New-Item -Path $folder -ItemType Directory -Force | Out-Null
$project = Join-Path $folder 'process-compose.yaml'
$parent = (Resolve-Path (Join-Path $PSScriptRoot 'tree-fixture-parent.ps1')).Path
$child = (Resolve-Path (Join-Path $PSScriptRoot 'tree-fixture-child.ps1')).Path
$parentPidFile = Join-Path $folder 'parent.pid'
$childPidFile = Join-Path $folder 'child.pid'
$supervisor = $null
$childPid = 0
$parentPid = 0

function Pick-FreePort {
    $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    try {
        $listener.Start()
        return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally { $listener.Stop() }
}
function Is-Listening([int]$Port) {
    $connection=[Net.Sockets.TcpClient]::new()
    try {
        $t=$connection.ConnectAsync('127.0.0.1',$Port)
        if (-not $t.Wait(150)) { return $false }
        return $connection.Connected
    }
    catch { return $false }
    finally { $connection.Dispose() }
}
function Is-Alive([int]$ProcessId) {
    if($ProcessId -le 0){return $false}
    return ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue))
}

try {
    $port = Pick-FreePort
    $managementPort = Pick-FreePort
    for($i=0;$i -lt 4 -and $managementPort -eq $port;$i++){ $managementPort = Pick-FreePort }
    if($managementPort -eq $port){throw 'Unable to allocate distinct disposable ports.'}

    # Process Compose v1.124.0 supports process entrypoint argv without
    # shell expansion. The project's explicit pwsh shell is used for exec
    # readiness probes. Exercise a path with both apostrophes and spaces.
    function QYaml([string]$text) {
        return "'" + $text.Replace("'", "''") + "'"
    }
    function QPowerShell([string]$text) {
        return "'" + $text.Replace("'", "''") + "'"
    }
    $probe = Join-Path $folder "health O'Brien.ps1"
    $probeMarker = Join-Path $folder 'probe-called.txt'
    Set-Content -LiteralPath $probe -Encoding utf8 -Value @'
param([string]$ParentPidFile, [string]$ChildPidFile, [string]$Marker)
if ((Test-Path -LiteralPath $ParentPidFile -PathType Leaf) -and
    (Test-Path -LiteralPath $ChildPidFile -PathType Leaf)) {
    Set-Content -LiteralPath $Marker -Value 'ok'
    exit 0
}
exit 1
'@
    $entry = @('pwsh','-NoProfile','-NonInteractive','-File',$parent,
        '-Child',$child,'-Port',[string]$port,
        '-ParentPidFile',$parentPidFile,'-ChildPidFile',$childPidFile)
    $probeCommand = '& ' + (QPowerShell $probe) +
        ' -ParentPidFile ' + (QPowerShell $parentPidFile) +
        ' -ChildPidFile ' + (QPowerShell $childPidFile) +
        ' -Marker ' + (QPowerShell $probeMarker) +
        '; if (-not $?) { exit 1 }'
    $yamlLines = @(
        'version: "0.5"'
        'shell:'
        '  shell_command: pwsh'
        '  shell_argument: -Command'
        'processes:'
        '  nested-child-tree:'
        '    entrypoint:'
    )
    $yamlLines += @($entry | ForEach-Object { '      - ' + (QYaml $_) })
    $yamlLines += @(
        '    readiness_probe:'
        '      exec:'
        '        command: ' + (QYaml $probeCommand)
        '      initial_delay_seconds: 1'
        '      period_seconds: 1'
        '      timeout_seconds: 4'
        '      failure_threshold: 15'
        '    availability:'
        '      restart: "no"'
    )
    $yaml = $yamlLines -join [Environment]::NewLine
    [IO.File]::WriteAllText($project,$yaml)
    $common = @('--address','127.0.0.1','--port',[string]$managementPort)
    # Start-Process flattens ArgumentList into a Windows command-line string.
    # Quote this single config-path argument explicitly, including spaces and
    # apostrophes. PowerShell's native call operator below remains unchanged.
    $quotedProject = '"' + $project.Replace('"', '\\"') + '"'
    $startArgs = $common + @('--disable-dotenv','--config',$quotedProject,
                             'up','--keep-project','--tui=false')
    $startParams = @{
        FilePath=$Binary
        ArgumentList=$startArgs
        PassThru=$true
        RedirectStandardOutput=(Join-Path $folder 'supervisor.out')
        RedirectStandardError=(Join-Path $folder 'supervisor.err')
    }
    $supervisor = Start-Process @startParams
    $ready = $false
    for($i=0;$i -lt 100;$i++){
        if ((Test-Path -LiteralPath $parentPidFile) -and
            (Test-Path -LiteralPath $childPidFile) -and (Is-Listening $port)) {
            $ready=$true
            break
        }
        if($supervisor.HasExited){break}
        Start-Sleep -Milliseconds 160
    }
    if(-not $ready){
        Write-Host "[DIAGNOSTIC] Supervisor exited: $($supervisor.HasExited)"
        foreach($file in @('supervisor.out','supervisor.err')){
            $log = Join-Path $folder $file
            if(Test-Path -LiteralPath $log){
                Write-Host "[DIAGNOSTIC] $file"
                Get-Content -LiteralPath $log -Tail 55 | ForEach-Object { Write-Host $_ }
            }
        }
        Write-Host "[DIAGNOSTIC] Parent marker: $(Test-Path $parentPidFile); child marker: $(Test-Path $childPidFile)"
        throw 'Nested test process never became ready.'
    }
    # Readiness must be executed through the specified pwsh shell.
    $probed = $false
    for ($i=0; $i -lt 60; $i++) {
        if (Test-Path -LiteralPath $probeMarker -PathType Leaf) {
            $probed = $true; break
        }
        Start-Sleep -Milliseconds 150
    }
    if (-not $probed) { throw 'The plain PowerShell health probe never executed.' }
    $unexpectedCmd = @(Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" |
        Where-Object { $_.ParentProcessId -eq $supervisor.Id })
    if ($unexpectedCmd.Count -gt 0) {
        throw 'Process Compose spawned cmd.exe despite native entrypoint/pwsh shell.'
    }
    $parentPid=[int](Get-Content -LiteralPath $parentPidFile -Raw)
    $childPid=[int](Get-Content -LiteralPath $childPidFile -Raw)
    if(-not (Is-Alive $parentPid) -or -not (Is-Alive $childPid)){
        throw 'Disposable parent and child are not both alive.'
    }

    & $Binary @common down
    if($LASTEXITCODE -ne 0){throw 'Process Compose down failed.'}
    $gone=$false
    for($i=0;$i -lt 90;$i++){
        if(-not (Is-Alive $parentPid) -and -not (Is-Alive $childPid) -and
           -not (Is-Listening $port)){
            $gone=$true
            break
        }
        Start-Sleep -Milliseconds 160
    }
    if(-not $gone){throw 'Down left nested PowerShell descendants or listener alive.'}
    Write-Host '[PASS] Process Compose terminated both disposable Windows descendants and freed their port.'
}
finally {
    # Cleanup only disposable CI fixture processes, never any user service.
    if($null -ne $supervisor -and -not $supervisor.HasExited){
        try { & taskkill.exe /T /F /PID $supervisor.Id *> $null } catch {}
    }
    if(Is-Alive $childPid){Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue}
    if(Is-Alive $parentPid){Stop-Process -Id $parentPid -Force -ErrorAction SilentlyContinue}
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}
