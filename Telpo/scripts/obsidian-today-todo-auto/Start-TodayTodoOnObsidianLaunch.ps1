#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(2, 60)][int]$PollSeconds = 5,
    [string]$ProcessName = 'Obsidian',
    [string]$RunnerScript,
    [string]$VaultRoot,
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
if ([string]::IsNullOrWhiteSpace($RunnerScript)) {
    $RunnerScript = Join-Path $ScriptDirectory 'Start-TodayTodoDailyRun.ps1'
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $VaultRoot '工作笔记\今日待办\今日待办自动生成运行日志.md'
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
        $today = Get-Date -Format 'yyyy-MM-dd'
        $initialContent = @"
---
title: 今日待办自动生成运行日志
tags:
  - 工作笔记
  - 今日待办
  - 自动化
  - 日志
created: $today
updated: $today
status: 常用
---

# 今日待办自动生成运行日志

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

function Invoke-Runner {
    if (-not (Test-Path -LiteralPath $RunnerScript -PathType Leaf)) {
        Write-LaunchLog -Message "Runner script not found: $RunnerScript"
        return
    }

    try {
        Write-LaunchLog -Message 'Detected Obsidian launch. Running today todo compensation once.'
        & $RunnerScript -Mode 'launch-compensation' -VaultRoot $VaultRoot -LogPath $LogPath
        Write-LaunchLog -Message 'Today todo compensation finished for current Obsidian session.'
    }
    catch {
        Write-LaunchLog -Message "Today todo compensation failed: $($_.Exception.Message)"
    }
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ObsidianTodayTodoOnLaunch', [ref]$createdNew)
if (-not $createdNew) {
    Write-LaunchLog -Message 'Today todo launch watcher is already running; exiting this instance.'
    exit 0
}

try {
    Write-LaunchLog -Message "Today todo launch watcher started. ProcessName=$ProcessName; PollSeconds=$PollSeconds"
    $wasRunning = Test-ObsidianRunning

    if ($wasRunning) {
        Invoke-Runner
    }

    while ($true) {
        Start-Sleep -Seconds $PollSeconds
        $isRunning = Test-ObsidianRunning

        if ($isRunning -and -not $wasRunning) {
            Invoke-Runner
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
