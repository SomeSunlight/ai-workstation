#requires -Version 7.4
<#
.SYNOPSIS
    Installs or verifies WSL 2, Ubuntu, the Linux repository checkout and the
    Linux host configuration.

.DESCRIPTION
    This script is the Windows implementation behind the public install.ps1
    entry point. It is idempotent and never unregisters or deletes a
    distribution.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Status', 'Verify')]
    [string]$Action = 'Install',

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$DistroName = 'Ubuntu-24.04',
    [string]$InstallLocation = 'C:\WSL\Ubuntu-24.04',
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser = 'moresunlight',
    [string]$RepositoryUrl = 'https://github.com/SomeSunlight/ai-workstation.git',
    [string]$RepositoryRef = 'main',
    [ValidatePattern('^\d+(MB|GB)$')]
    [string]$WslMemory = '48GB',
    [ValidatePattern('^\d+(MB|GB)$')]
    [string]$WslSwap = '8GB',
    [string]$ShortcutName = 'AI Workstation',
    [switch]$NoShortcuts,

    [switch]$NoAutomaticRestart,
    [switch]$SkipLinuxInstall,
    [switch]$ResumeAfterReboot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:StateRoot = Join-Path $env:LOCALAPPDATA 'AiWorkstationBootstrap'
$script:LogRoot = Join-Path $script:StateRoot 'logs'
$script:StagedRoot = Join-Path $script:StateRoot 'source'
$script:StagedEntryPoint = Join-Path $script:StagedRoot 'install.ps1'
$script:RunOncePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$script:RunOnceName = 'AiWorkstationResume'
$script:TranscriptStarted = $false
$script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:VersionsPath = Join-Path $script:RepositoryRoot 'config\versions.json'
$script:DownloadsRoot = Join-Path $script:StateRoot 'downloads'

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)

    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor DarkGray
}

function Write-Step {
    param(
        [Parameter(Mandatory)][string]$Text,
        [ValidateSet('Info', 'Ok', 'Warning')]
        [string]$Level = 'Info'
    )

    $prefix = switch ($Level) {
        'Info' { '[..]' }
        'Ok' { '[OK]' }
        'Warning' { '[!!]' }
    }
    $color = switch ($Level) {
        'Info' { 'Gray' }
        'Ok' { 'Green' }
        'Warning' { 'Yellow' }
    }

    Write-Host "$prefix $Text" -ForegroundColor $color
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-Log {
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
    $path = Join-Path $script:LogRoot "windows-install-$($script:RunId).log"

    try {
        Start-Transcript -Path $path -Append | Out-Null
        $script:TranscriptStarted = $true
        Write-Step "Log: $path"
    }
    catch {
        Write-Step "Could not start transcript: $($_.Exception.Message)" Warning
    }
}

function Stop-Log {
    if ($script:TranscriptStarted) {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
        }
    }
}

function Stage-Installer {
    $sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

    if ($sourceRoot -ieq $script:StagedRoot) {
        return
    }

    if (Test-Path -LiteralPath $script:StagedRoot) {
        Remove-Item -LiteralPath $script:StagedRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $script:StagedRoot -Force | Out-Null

    Get-ChildItem -LiteralPath $sourceRoot -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $script:StagedRoot -Recurse -Force
    }
}

function Get-InvocationArguments {
    param([switch]$ForResume)

    $arguments = @(
        '-NoLogo'
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        ('"{0}"' -f $script:StagedEntryPoint)
        '-Action'
        $Action
        '-DistroName'
        ('"{0}"' -f $DistroName)
        '-InstallLocation'
        ('"{0}"' -f $InstallLocation)
        '-LinuxUser'
        ('"{0}"' -f $LinuxUser)
        '-RepositoryUrl'
        ('"{0}"' -f $RepositoryUrl)
        '-RepositoryRef'
        ('"{0}"' -f $RepositoryRef)
        '-WslMemory'
        ('"{0}"' -f $WslMemory)
        '-WslSwap'
        ('"{0}"' -f $WslSwap)
        '-ShortcutName'
        ('"{0}"' -f $ShortcutName)
    )

    if ($NoShortcuts) {
        $arguments += '-NoShortcuts'
    }
    if ($NoAutomaticRestart) {
        $arguments += '-NoAutomaticRestart'
    }
    if ($SkipLinuxInstall) {
        $arguments += '-SkipLinuxInstall'
    }
    if ($ForResume) {
        $arguments += '-ResumeAfterReboot'
    }

    return $arguments
}

function Restart-Elevated {
    Stage-Installer

    $pwsh = (Get-Process -Id $PID).Path
    $arguments = @('-NoExit') + (Get-InvocationArguments)

    Write-Host ''
    Write-Host '[..] Administrator rights are required.' -ForegroundColor Yellow
    Write-Host '[..] An elevated PowerShell window will open and stay open after the installer finishes.' -ForegroundColor Yellow
    Write-Host '[..] Continue watching that elevated window. This original shell can return to the prompt.' -ForegroundColor Yellow
    Write-Host ''

    Start-Process -FilePath $pwsh -ArgumentList $arguments -Verb RunAs | Out-Null
    exit 0
}

function Invoke-Wsl {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    & wsl.exe @Arguments
    $code = $LASTEXITCODE

    if (-not $AllowFailure -and $code -ne 0) {
        throw "wsl.exe failed with exit code ${code}: $($Arguments -join ' ')"
    }

    if ($AllowFailure) {
        return $code
    }
}

function Get-Distros {
    $output = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    return @(
        $output |
            ForEach-Object { ($_ -replace "`0", '').Trim() } |
            Where-Object { $_ }
    )
}

function Test-WslPlatform {
    & wsl.exe --version *> $null
    return $LASTEXITCODE -eq 0
}

function Register-ResumeAndRestart {
    Stage-Installer

    $pwsh = (Get-Process -Id $PID).Path
    $command = '"{0}" {1}' -f $pwsh, ((Get-InvocationArguments -ForResume) -join ' ')

    New-Item -Path $script:RunOncePath -Force | Out-Null
    New-ItemProperty `
        -Path $script:RunOncePath `
        -Name $script:RunOnceName `
        -Value $command `
        -PropertyType String `
        -Force | Out-Null

    if ($NoAutomaticRestart) {
        Write-Step 'A Windows restart is required. Restart manually; the installer resumes at the next sign-in.' Warning
        exit 0
    }

    Write-Step 'Windows will restart to finish WSL installation.' Warning
    Restart-Computer -Force
}

function Ensure-WslPlatform {
    if (Test-WslPlatform) {
        Write-Step 'WSL platform is available.' Ok
        Write-Step 'Checking for WSL updates. This can take several minutes and may produce little output.'
        Invoke-Wsl -Arguments @('--update')
        Write-Step 'WSL update check completed.' Ok
        return
    }

    Write-Step 'Installing the WSL platform without a distribution.'
    Invoke-Wsl -Arguments @('--install', '--no-distribution') | Out-Null
    Register-ResumeAndRestart
}

function Test-WslHelpOption {
    param([Parameter(Mandatory)][string]$Option)

    $text = (& wsl.exe --help 2>&1 | Out-String) -replace "`0", ''
    return $text -match [regex]::Escape($Option)
}

function Get-VersionConfiguration {
    if (-not (Test-Path -LiteralPath $script:VersionsPath -PathType Leaf)) {
        throw "Version configuration not found: $($script:VersionsPath)"
    }

    return Get-Content -LiteralPath $script:VersionsPath -Raw | ConvertFrom-Json
}

function Get-DistroBasePath {
    param([Parameter(Mandatory)][string]$Name)

    $lxss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    if (-not (Test-Path -LiteralPath $lxss)) {
        return $null
    }

    foreach ($key in Get-ChildItem -LiteralPath $lxss) {
        $properties = Get-ItemProperty -LiteralPath $key.PSPath
        if ($properties.DistributionName -eq $Name) {
            return $properties.BasePath
        }
    }

    return $null
}

function Ensure-UbuntuImage {
    $configuration = Get-VersionConfiguration
    $url = [string]$configuration.versions.ubuntu.wsl_image_url
    $expectedHash = ([string]$configuration.versions.ubuntu.wsl_image_sha256).ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($expectedHash)) {
        throw 'Ubuntu WSL image URL or checksum is missing from config\versions.json.'
    }

    New-Item -ItemType Directory -Path $script:DownloadsRoot -Force | Out-Null
    $fileName = [IO.Path]::GetFileName(([Uri]$url).AbsolutePath)
    $target = Join-Path $script:DownloadsRoot $fileName

    $valid = $false
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $actualHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $valid = $actualHash -eq $expectedHash
        if (-not $valid) {
            Write-Step 'Cached Ubuntu image has the wrong checksum and will be downloaded again.' Warning
            Remove-Item -LiteralPath $target -Force
        }
    }

    if (-not $valid) {
        Write-Step "Downloading pinned Ubuntu WSL image: $fileName"
        Invoke-WebRequest -Uri $url -OutFile $target
    }

    $actualHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        Remove-Item -LiteralPath $target -Force
        throw "Ubuntu image checksum mismatch. Expected $expectedHash, found $actualHash."
    }

    Write-Step 'Pinned Ubuntu WSL image checksum is valid.' Ok
    return $target
}

function Ensure-Distro {
    if ($DistroName -in (Get-Distros)) {
        $basePath = Get-DistroBasePath -Name $DistroName
        if ($null -ne $basePath) {
            $normalizedBasePath = ([string]$basePath) -replace '^\\\?\', ''
            $expected = [IO.Path]::GetFullPath($InstallLocation).TrimEnd('\')
            $actual = [IO.Path]::GetFullPath($normalizedBasePath).TrimEnd('\')
            if ($actual -ine $expected) {
                throw "Distribution '$DistroName' exists at '$actual', not at '$expected'."
            }
        }

        Write-Step "Distribution '$DistroName' already exists." Ok
        return
    }

    if (Test-Path -LiteralPath $InstallLocation) {
        $existingItems = @(Get-ChildItem -LiteralPath $InstallLocation -Force)
        if ($existingItems.Count -gt 0) {
            throw "Install location is not empty: $InstallLocation"
        }
    }
    else {
        New-Item -ItemType Directory -Path $InstallLocation -Force | Out-Null
    }

    if (-not (Test-WslHelpOption -Option '--from-file')) {
        throw "This WSL release does not support --from-file. Run 'wsl --update' and retry."
    }
    if (-not (Test-WslHelpOption -Option '--name')) {
        throw "This WSL release does not support custom distribution names. Run 'wsl --update' and retry."
    }

    $imagePath = Ensure-UbuntuImage

    $arguments = @(
        '--install'
        '--from-file'
        $imagePath
        '--name'
        $DistroName
        '--location'
        $InstallLocation
        '--no-launch'
    )

    Write-Step "Installing the pinned Ubuntu image as '$DistroName' in $InstallLocation."
    Invoke-Wsl -Arguments $arguments | Out-Null

    if ($DistroName -notin (Get-Distros)) {
        throw "Distribution '$DistroName' was not registered."
    }

    Write-Step "Distribution '$DistroName' is installed." Ok
}

function ConvertTo-BashLiteral {
    param([Parameter(Mandatory)][string]$Value)

    $singleQuoteEscape = @'
'"'"'
'@
    $singleQuoteEscape = $singleQuoteEscape.Trim()

    return "'" + $Value.Replace("'", $singleQuoteEscape) + "'"
}

function Invoke-Bash {
    param(
        [Parameter(Mandatory)][string]$Script,
        [string]$User = 'root'
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($Script)
    $encoded = [Convert]::ToBase64String($bytes)

    Invoke-Wsl -Arguments @(
        '--distribution'
        $DistroName
        '--user'
        $User
        '--'
        'bash'
        '-lc'
        "echo $encoded | base64 -d | bash"
    ) | Out-Null
}

function Ensure-LinuxPrerequisites {
    Write-Step 'Installing minimal packages in the Ubuntu distribution.'
    Invoke-Bash -Script @'
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  python3
'@
    Write-Step 'Minimal Ubuntu packages are installed.' Ok
}

function Ensure-LinuxUser {
    $userLiteral = ConvertTo-BashLiteral -Value $LinuxUser
    $existsScript = "id -u $userLiteral >/dev/null 2>&1"

    & wsl.exe --distribution $DistroName --user root -- bash -lc $existsScript *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Step "Linux user '$LinuxUser' already exists." Ok
    }
    else {
        Write-Step "Creating Linux user '$LinuxUser'."
        Invoke-Bash -Script "useradd --create-home --user-group --shell /bin/bash --groups sudo $userLiteral"

        Write-Host ''
        Write-Host "Set the Linux password for '$LinuxUser':" -ForegroundColor Cyan
        Invoke-Wsl -Arguments @(
            '--distribution'
            $DistroName
            '--user'
            'root'
            '--'
            'passwd'
            $LinuxUser
        ) | Out-Null
    }

    Invoke-Bash -Script "usermod --append --groups sudo $userLiteral"

    $configuration = @"
set -e
python3 - <<'PY'
from configparser import ConfigParser
from pathlib import Path

path = Path('/etc/wsl.conf')
config = ConfigParser()
config.optionxform = str
if path.exists():
    config.read(path)

if not config.has_section('boot'):
    config.add_section('boot')
config.set('boot', 'systemd', 'true')

if not config.has_section('user'):
    config.add_section('user')
config.set('user', 'default', '$LinuxUser')

with path.open('w', encoding='utf-8') as handle:
    config.write(handle, space_around_delimiters=False)
PY
"@

    Invoke-Bash -Script $configuration
    Invoke-Wsl -Arguments @('--terminate', $DistroName) | Out-Null
    Start-Sleep -Seconds 2

    $actual = (
        & wsl.exe --distribution $DistroName -- bash -lc 'id -un' 2>$null |
            Select-Object -First 1
    ).Trim()

    if ($actual -ne $LinuxUser) {
        throw "Expected default Linux user '$LinuxUser', found '$actual'."
    }

    Write-Step "Default Linux user is '$LinuxUser'." Ok
}

function Merge-WslConfig {
    $path = Join-Path $env:USERPROFILE '.wslconfig'

    if (Test-Path -LiteralPath $path) {
        $lines = [Collections.Generic.List[string]](Get-Content -LiteralPath $path)
    }
    else {
        $lines = [Collections.Generic.List[string]]::new()
    }

    $start = -1
    $end = $lines.Count

    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -ieq '[wsl2]') {
            $start = $index
            continue
        }

        if (
            $start -ge 0 -and
            $index -gt $start -and
            $lines[$index].Trim() -match '^\[.+\]$'
        ) {
            $end = $index
            break
        }
    }

    if ($start -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') {
            $lines.Add('')
        }

        $start = $lines.Count
        $lines.Add('[wsl2]')
        $end = $lines.Count
    }

    $settings = [ordered]@{
        memory = $WslMemory
        swap = $WslSwap
    }

    foreach ($key in $settings.Keys) {
        $found = $false

        for ($index = $start + 1; $index -lt $end; $index++) {
            if ($lines[$index] -match "^\s*$key\s*=") {
                $lines[$index] = "$key=$($settings[$key])"
                $found = $true
                break
            }
        }

        if (-not $found) {
            $lines.Insert($end, "$key=$($settings[$key])")
            $end++
        }
    }

    Set-Content -LiteralPath $path -Value $lines -Encoding utf8NoBOM
    Write-Step "Updated $path with memory=$WslMemory and swap=$WslSwap." Ok
}

function Get-LinuxRepositoryPath {
    return "/home/$LinuxUser/ai-workstation"
}

function Get-ShortcutDisplayName {
    if ($DistroName -eq 'Ubuntu-24.04') {
        return $ShortcutName
    }

    return "$ShortcutName ($DistroName)"
}

function New-AiwShortcut {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
    if (-not (Test-Path -LiteralPath $wslExe -PathType Leaf)) {
        throw "wsl.exe not found at $wslExe"
    }

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    $linuxPath = Get-LinuxRepositoryPath
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $wslExe
    $shortcut.Arguments = ('--distribution "{0}" --cd "{1}"' -f $DistroName, $linuxPath)
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = "$wslExe,0"
    $shortcut.Description = "Open $DisplayName in WSL at $linuxPath"
    $shortcut.Save()
}

function Ensure-WindowsShortcuts {
    if ($NoShortcuts) {
        Write-Step 'Windows shortcuts were skipped by request.' Warning
        return
    }

    $displayName = Get-ShortcutDisplayName
    $shortcutFileName = "$displayName.lnk"
    $desktop = [Environment]::GetFolderPath('Desktop')
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

    New-AiwShortcut -Path (Join-Path $desktop $shortcutFileName) -DisplayName $displayName
    New-AiwShortcut -Path (Join-Path $startMenu $shortcutFileName) -DisplayName $displayName

    Write-Step "Created Windows shortcuts: $displayName" Ok
    Write-Step "Start later from the Windows Start Menu: $displayName"
}

function Ensure-LinuxRepository {
    $repositoryPath = Get-LinuxRepositoryPath
    $repositoryLiteral = ConvertTo-BashLiteral -Value $repositoryPath
    $urlLiteral = ConvertTo-BashLiteral -Value $RepositoryUrl
    $refLiteral = ConvertTo-BashLiteral -Value $RepositoryRef
    $userLiteral = ConvertTo-BashLiteral -Value $LinuxUser

    Invoke-Bash -Script @"
set -euo pipefail
if [ -d $repositoryLiteral/.git ]; then
  chown -R $userLiteral $repositoryLiteral
fi
"@

    Invoke-Bash -User $LinuxUser -Script @"
set -euo pipefail
if [ -d $repositoryLiteral/.git ]; then
  cd $repositoryLiteral
  git fetch --prune origin
  git checkout $refLiteral
  git pull --ff-only origin $refLiteral
elif [ -e $repositoryLiteral ]; then
  echo 'Target exists but is not a Git repository: $repositoryPath' >&2
  exit 1
else
  git clone --branch $refLiteral --single-branch $urlLiteral $repositoryLiteral
fi
chmod +x $repositoryLiteral/install.sh $repositoryLiteral/bin/aiw $repositoryLiteral/bootstrap/linux/install.sh
"@

    Write-Step "Linux repository is available at $repositoryPath." Ok
}

function Invoke-LinuxInstall {
    if ($SkipLinuxInstall) {
        Write-Step 'Linux host installation was skipped.' Warning
        return
    }

    Write-Section 'Linux host installation'
    Invoke-Wsl -Arguments @(
        '--distribution'
        $DistroName
        '--user'
        $LinuxUser
        '--'
        'bash'
        '-lc'
        'cd ~/ai-workstation && ./install.sh install --yes'
    )
    Write-Step 'Linux host installation completed.' Ok
}

function Show-Status {
    Write-Section 'AI Workstation Windows status'
    Write-Step "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Step "WSL platform: $(if (Test-WslPlatform) { 'available' } else { 'missing' })"

    $distros = Get-Distros
    Write-Step "Distributions: $(if ($distros.Count) { $distros -join ', ' } else { 'none' })"

    $displayName = Get-ShortcutDisplayName
    $desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) "$displayName.lnk"
    $startMenuShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs') "$displayName.lnk"
    Write-Step "Desktop shortcut: $(if (Test-Path -LiteralPath $desktopShortcut) { 'present' } else { 'missing' })"
    Write-Step "Start Menu shortcut: $(if (Test-Path -LiteralPath $startMenuShortcut) { 'present' } else { 'missing' })"

    if ($DistroName -in $distros) {
        Invoke-Wsl -Arguments @(
            '--distribution'
            $DistroName
            '--'
            'bash'
            '-lc'
            'if [ -x ~/ai-workstation/bin/aiw ]; then ~/ai-workstation/bin/aiw status; else echo "Linux repository not installed"; fi'
        )
    }
}

function Verify-All {
    if (-not (Test-WslPlatform)) {
        throw 'WSL platform is missing.'
    }

    if ($DistroName -notin (Get-Distros)) {
        throw "Distribution '$DistroName' is missing."
    }

    $release = (
        & wsl.exe --distribution $DistroName -- bash -lc '. /etc/os-release; printf %s "$VERSION_ID"'
    ).Trim()

    if ($release -ne '24.04') {
        throw "Expected Ubuntu 24.04, found '$release'."
    }

    Invoke-Wsl -Arguments @(
        '--distribution'
        $DistroName
        '--user'
        $LinuxUser
        '--'
        'bash'
        '-lc'
        'cd ~/ai-workstation && ./install.sh verify'
    )

    Write-Step 'Windows and Linux verification completed successfully.' Ok
}

try {
    if ($Action -eq 'Install' -and -not (Test-Administrator)) {
        Restart-Elevated
    }

    Start-Log
    Write-Section 'AI Workstation Windows installer'
    Write-Step "Action: $Action"
    Write-Step "Distribution: $DistroName"
    Write-Step "Location: $InstallLocation"

    switch ($Action) {
        'Status' {
            Show-Status
        }
        'Verify' {
            Verify-All
        }
        'Install' {
            Ensure-WslPlatform
            Merge-WslConfig
            Ensure-Distro
            Ensure-LinuxPrerequisites
            Ensure-LinuxUser
            Ensure-LinuxRepository
            Ensure-WindowsShortcuts
            Invoke-LinuxInstall
            Write-Step 'AI Workstation installation completed successfully.' Ok
            Write-Step 'Run ".\install.ps1 -Action Status" to show the current installation state.'
        }
    }
}
catch {
    Write-Host ''
    Write-Host '[XX] Windows installation failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
finally {
    Stop-Log
}
