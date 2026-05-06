#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(5, 3600)][int]$PollSeconds = 20,
    [ValidateRange(10, 3600)][int]$DebounceSeconds = 45,
    [string]$VaultRoot,
    [string]$PipelineScript,
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

if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
    $VaultRoot = 'C:\Users\18826\Documents\work_doc_ob\Telpo'
}
if ([string]::IsNullOrWhiteSpace($PipelineScript)) {
    $PipelineScript = Join-Path $VaultRoot '.claude\plugin_doc_pipeline.js'
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $ScriptDirectory 'logs\obsidian-plugin-doc-auto-watch.log'
}

$pluginsRoot = Join-Path $VaultRoot '.obsidian\plugins'
$communityPluginsPath = Join-Path $VaultRoot '.obsidian\community-plugins.json'

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

function Get-PluginsSignature {
    $parts = New-Object System.Collections.Generic.List[string]

    if (Test-Path -LiteralPath $communityPluginsPath -PathType Leaf) {
        $item = Get-Item -LiteralPath $communityPluginsPath
        $parts.Add("community:$($item.Length):$($item.LastWriteTimeUtc.Ticks)")
    }
    else {
        $parts.Add('community:missing')
    }

    if (Test-Path -LiteralPath $pluginsRoot -PathType Container) {
        $manifests = Get-ChildItem -LiteralPath $pluginsRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $manifest = Join-Path $_.FullName 'manifest.json'
                if (Test-Path -LiteralPath $manifest -PathType Leaf) {
                    Get-Item -LiteralPath $manifest
                }
            } |
            Sort-Object FullName

        foreach ($manifest in $manifests) {
            $parts.Add("manifest:$($manifest.FullName):$($manifest.Length):$($manifest.LastWriteTimeUtc.Ticks)")
        }
    }
    else {
        $parts.Add('plugins:missing')
    }

    return ($parts -join '|')
}

function Invoke-Pipeline {
    if (-not (Test-Path -LiteralPath $PipelineScript -PathType Leaf)) {
        Write-WatchLog -Message "Pipeline script not found: $PipelineScript"
        return
    }

    try {
        Write-WatchLog -Message 'Running plugin documentation pipeline.'
        $output = & node $PipelineScript 2>&1
        foreach ($line in $output) {
            Write-WatchLog -Message ([string]$line)
        }
        Write-WatchLog -Message 'Pipeline finished.'
    }
    catch {
        Write-WatchLog -Message "Pipeline failed: $($_.Exception.Message)"
    }
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ObsidianPluginDocAutoWatch', [ref]$createdNew)
if (-not $createdNew) {
    Write-WatchLog -Message 'Plugin documentation watcher is already running; exiting this instance.'
    exit 0
}

try {
    Write-WatchLog -Message "Plugin documentation watcher started. PollSeconds=$PollSeconds; DebounceSeconds=$DebounceSeconds"
    $lastSignature = Get-PluginsSignature
    $lastRunUtc = [datetime]::MinValue

    Invoke-Pipeline
    $lastRunUtc = (Get-Date).ToUniversalTime()
    $lastSignature = Get-PluginsSignature

    while ($true) {
        Start-Sleep -Seconds $PollSeconds
        $currentSignature = Get-PluginsSignature
        if ($currentSignature -ne $lastSignature) {
            $nowUtc = (Get-Date).ToUniversalTime()
            if (($nowUtc - $lastRunUtc).TotalSeconds -lt $DebounceSeconds) {
                Write-WatchLog -Message 'Detected plugin file changes but still inside debounce window; waiting for next poll.'
                $lastSignature = $currentSignature
                continue
            }

            Write-WatchLog -Message 'Detected plugin installation/config change; triggering pipeline.'
            Invoke-Pipeline
            $lastRunUtc = (Get-Date).ToUniversalTime()
            $lastSignature = Get-PluginsSignature
        }
    }
}
finally {
    if ($null -ne $mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
