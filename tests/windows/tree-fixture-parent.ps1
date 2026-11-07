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
$argsList=@('-NoProfile','-NonInteractive','-File',$Child,'-Port',[string]$Port,'-ReadyFile',$ChildPidFile)
$childProcess=Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList $argsList -PassThru -NoNewWindow
[IO.File]::WriteAllText($ParentPidFile,[string]$PID)
while(-not $childProcess.HasExited){Start-Sleep -Milliseconds 300}
exit $childProcess.ExitCode
