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
$folder = Join-Path $env:RUNNER_TEMP ('aiw-pc-tree-' + [guid]::NewGuid().ToString('N'))
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

    # The fixture only starts temporary PowerShell processes and a loopback TCP
    # listener. Paths come from the CI checkout, never from the user host.
    $cmd = 'pwsh -NoProfile -NonInteractive -File "' + $parent +
        '" -Child "' + $child + '" -Port ' + $port +
        ' -ParentPidFile "' + $parentPidFile +
        '" -ChildPidFile "' + $childPidFile + '"'
    $yaml = @(
        'version: "0.5"'
        'processes:'
        '  nested-child-tree:'
        "    command: '$cmd'"
        '    availability:'
        '      restart: "no"'
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText($project,$yaml)
    $common = @('--address','127.0.0.1','--port',[string]$managementPort)
    $startArgs = $common + @('--disable-dotenv','--config',$project,
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
    if(-not $ready){throw 'Nested test process never became ready; inspect CI log.'}
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
