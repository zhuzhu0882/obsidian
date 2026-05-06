#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(2, 60)][int]$PollSeconds = 5,
    [string]$ProcessName = 'Obsidian',
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
    $LogPath = Join-Path $VaultRoot 'AI笔记\插件使用经验\插件自动建档运行日志.md'
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Ensure-MarkdownLog {
    $logDir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        Ensure-Directory -Path $logDir
    }

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        $initialContent = @"
---
title: 插件自动建档运行日志
tags:
  - obsidian
  - 插件
  - 自动化
  - 日志
category: 插件使用经验
created: 2026-05-03
updated: 2026-05-03
status: 常用
---

# 插件自动建档运行日志

> 相关入口：[[AI笔记/插件使用经验/Obsidian插件目录]]

## 运行记录

"@
        Set-Content -LiteralPath $LogPath -Encoding UTF8 -Value $initialContent
    }
}

function Write-LaunchLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    Ensure-MarkdownLog
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value "- [$stamp] $Message"
}

function Test-ObsidianRunning {
    return $null -ne (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Invoke-Pipeline {
    if (-not (Test-Path -LiteralPath $PipelineScript -PathType Leaf)) {
        Write-LaunchLog -Message "Pipeline script not found: $PipelineScript"
        return
    }

    try {
        Write-LaunchLog -Message 'Detected Obsidian launch. Running plugin documentation pipeline once.'
        $output = & node $PipelineScript 2>&1
        foreach ($line in $output) {
            Write-LaunchLog -Message ([string]$line)
        }
        Write-LaunchLog -Message 'Pipeline finished for current Obsidian session.'
    }
    catch {
        Write-LaunchLog -Message "Pipeline failed: $($_.Exception.Message)"
    }
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ObsidianPluginDocOnLaunch', [ref]$createdNew)
if (-not $createdNew) {
    Write-LaunchLog -Message 'Obsidian launch watcher is already running; exiting this instance.'
    exit 0
}

try {
    Write-LaunchLog -Message "Obsidian launch watcher started. ProcessName=$ProcessName; PollSeconds=$PollSeconds"
    $wasRunning = Test-ObsidianRunning

    if ($wasRunning) {
        Invoke-Pipeline
    }

    while ($true) {
        Start-Sleep -Seconds $PollSeconds
        $isRunning = Test-ObsidianRunning

        if ($isRunning -and -not $wasRunning) {
            Invoke-Pipeline
        }

        $wasRunning = $isRunning
    }
}
finally {
    if ($null -ne $mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
