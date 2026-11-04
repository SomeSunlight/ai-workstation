#Requires -Version 7.4
# Disposable Windows Process Compose regression child. Never used on user hosts.
param([Parameter(Mandatory)][int]$Port,[Parameter(Mandatory)][string]$ReadyFile)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
$listener.Start()
[IO.File]::WriteAllText($ReadyFile,[string]$PID)
while($true){Start-Sleep -Milliseconds 300}
