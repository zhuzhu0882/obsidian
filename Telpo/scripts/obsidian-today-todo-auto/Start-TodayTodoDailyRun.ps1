#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('scheduled', 'launch-compensation', 'manual')][string]$Mode = 'manual',
    [string]$VaultRoot,
    [string]$PipelineScript,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
    $VaultRoot = 'C:\Users\18826\Documents\work_doc_ob\Telpo'
}
if ([string]::IsNullOrWhiteSpace($PipelineScript)) {
    $PipelineScript = Join-Path $VaultRoot '.claude\today_todo_pipeline.js'
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

function Ensure-MarkdownLogFromSummary {
    param([Parameter(Mandatory = $true)]$Summary)

    $targetLogPath = [string]$Summary.markdownLogPath
    if ([string]::IsNullOrWhiteSpace($targetLogPath)) {
        $targetLogPath = $LogPath
    }

    $logDir = Split-Path -Parent $targetLogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    }

    if (-not [System.IO.File]::Exists($targetLogPath)) {
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
        [System.IO.File]::WriteAllText($targetLogPath, $initialContent, [System.Text.Encoding]::UTF8)
    }

    return $targetLogPath
}

function Append-RunLog {
    param(
        [Parameter(Mandatory = $true)][string]$TargetLogPath,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    [System.IO.File]::AppendAllText($TargetLogPath, "- [$stamp] $Message`r`n", [System.Text.Encoding]::UTF8)
}

function Write-RunLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    $logDir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    }

    if (-not [System.IO.File]::Exists($LogPath)) {
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
        [System.IO.File]::WriteAllText($LogPath, $initialContent, [System.Text.Encoding]::UTF8)
    }

    Append-RunLog -TargetLogPath $LogPath -Message $Message
}

function Refresh-SystemTaskNotifierPlan {
    $notifierScript = Join-Path $VaultRoot 'scripts\obsidian-task-notifier\Start-ObsidianTaskNotifier.ps1'
    if (-not (Test-Path -LiteralPath $notifierScript -PathType Leaf)) {
        Write-RunLog -Message "mode=$Mode notifier script not found: $notifierScript"
        return
    }

    try {
        & $notifierScript -RunOnce | Out-Null
        Write-RunLog -Message "mode=$Mode system task notifier refresh completed"
    }
    catch {
        Write-RunLog -Message "mode=$Mode system task notifier refresh failed: $($_.Exception.Message)"
    }
}

function Invoke-TodayTodoPipeline {
    if (-not (Test-Path -LiteralPath $PipelineScript -PathType Leaf)) {
        Write-RunLog -Message "Pipeline script not found: $PipelineScript"
        throw "Pipeline script not found: $PipelineScript"
    }

    $output = & node $PipelineScript --mode $Mode --vault $VaultRoot 2>&1
    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-RunLog -Message "mode=$Mode pipeline produced no output"
        return
    }

    try {
        $summary = $text | ConvertFrom-Json
        Write-RunLog -Message "mode=$Mode status=$($summary.status) reason=$($summary.reason) today=$($summary.todayDate) created=$($summary.createdTodayFile) appendedTasks=$($summary.appendedTaskCount) plannerCreated=$($summary.plannerSectionCreated) target=$($summary.todayFile) source=$($summary.yesterdayFile)"
    }
    catch {
        Write-RunLog -Message "mode=$Mode raw-output=$text"
    }
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ObsidianTodayTodoDailyRun', [ref]$createdNew)
if (-not $createdNew) {
    Write-RunLog -Message "mode=$Mode another today-todo run is already active; exiting"
    exit 0
}

try {
    Write-RunLog -Message "mode=$Mode start"
    Invoke-TodayTodoPipeline
    Refresh-SystemTaskNotifierPlan
    Write-RunLog -Message "mode=$Mode finish"
}
catch {
    Write-RunLog -Message "mode=$Mode failed: $($_.Exception.Message)"
    throw
}
finally {
    if ($null -ne $mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
