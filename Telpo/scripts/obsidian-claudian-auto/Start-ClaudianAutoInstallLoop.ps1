#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(10, 86400)][int]$IntervalSeconds = 300,
    [ValidateRange(5, 3600)][int]$PollSeconds = 30,
    [string]$InstallerScript,
    [string]$ObsidianConfigPath,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDirectory = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).ProviderPath
}

if ([string]::IsNullOrWhiteSpace($InstallerScript)) {
    $InstallerScript = Join-Path $ScriptDirectory 'Install-ClaudianToObsidianVaults.ps1'
}
if ([string]::IsNullOrWhiteSpace($ObsidianConfigPath)) {
    $ObsidianConfigPath = Join-Path $env:APPDATA 'obsidian\obsidian.json'
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $ScriptDirectory 'logs\obsidian-plugin-auto-watch.log'
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Write-WatchLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logDir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        Ensure-Directory -Path $logDir
    }

    Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value "[$stamp] $Message"
}

function Get-RegistryLastWriteUtc {
    if (Test-Path -LiteralPath $ObsidianConfigPath -PathType Leaf) {
        return (Get-Item -LiteralPath $ObsidianConfigPath).LastWriteTimeUtc
    }

    return $null
}

function Invoke-ObsidianPluginInstall {
    if (-not (Test-Path -LiteralPath $InstallerScript -PathType Leaf)) {
        Write-WatchLog -Message "Installer script not found: $InstallerScript"
        return
    }

    try {
        Write-WatchLog -Message "Running installer: $InstallerScript"
        $output = & $InstallerScript 2>&1
        foreach ($line in $output) {
            Write-WatchLog -Message ([string]$line)
        }
        Write-WatchLog -Message 'Installer finished.'
    }
    catch {
        Write-WatchLog -Message "Installer failed: $($_.Exception.Message)"
    }
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ObsidianPluginAutoInstall', [ref]$createdNew)
if (-not $createdNew) {
    Write-WatchLog -Message 'Watcher is already running; exiting this instance.'
    exit 0
}

try {
    Write-WatchLog -Message "Plugin watcher started. PollSeconds=$PollSeconds; IntervalSeconds=$IntervalSeconds"
    $lastKnownWrite = Get-RegistryLastWriteUtc
    $lastRunUtc = [datetime]::MinValue

    Invoke-ObsidianPluginInstall
    $lastRunUtc = (Get-Date).ToUniversalTime()
    $lastKnownWrite = Get-RegistryLastWriteUtc

    while ($true) {
        Start-Sleep -Seconds $PollSeconds

        $nowUtc = (Get-Date).ToUniversalTime()
        $currentWrite = Get-RegistryLastWriteUtc
        $changed = ($null -ne $currentWrite -and $null -ne $lastKnownWrite -and $currentWrite -ne $lastKnownWrite) -or ($null -ne $currentWrite -and $null -eq $lastKnownWrite)
        $due = (($nowUtc - $lastRunUtc).TotalSeconds -ge $IntervalSeconds)

        if ($changed -or $due) {
            if ($changed) {
                Write-WatchLog -Message "Obsidian vault registry changed: $ObsidianConfigPath"
            }
            Invoke-ObsidianPluginInstall
            $lastRunUtc = (Get-Date).ToUniversalTime()
            $lastKnownWrite = Get-RegistryLastWriteUtc
        }
    }
}
finally {
    if ($null -ne $mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}



