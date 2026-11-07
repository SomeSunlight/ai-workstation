#Requires -Version 7.4
# Disposable supervisor parent, which launches one nested child TCP listener.
param(
 [Parameter(Mandatory)][string]$Child,
 [Parameter(Mandatory)][int]$Port,
 [Parameter(Mandatory)][string]$ChildPidFile,
 [Parameter(Mandatory)][string]$ParentPidFile
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Start-Process flattens ArgumentList, so quote disposable child paths
# explicitly when the CI directory contains spaces and apostrophes.
$quotedChild = '"' + $Child.Replace('"', '\\"') + '"'
$quotedReady = '"' + $ChildPidFile.Replace('"', '\\"') + '"'
$argsList=@('-NoProfile','-NonInteractive','-File',$quotedChild,
    '-Port',[string]$Port,'-ReadyFile',$quotedReady)
$childProcess=Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList $argsList -PassThru -NoNewWindow
[IO.File]::WriteAllText($ParentPidFile,[string]$PID)
while(-not $childProcess.HasExited){Start-Sleep -Milliseconds 300}
exit $childProcess.ExitCode
