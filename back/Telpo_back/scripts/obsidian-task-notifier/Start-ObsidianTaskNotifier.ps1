#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(10, 300)][int]$PollSeconds = 30,
    [string]$VaultRoot,
    [string]$PluginDataPath,
    [string]$StatePath,
    [string]$TodayTodoDir,
    [string]$LogPath,
    [switch]$RunOnce,
    [switch]$TestToast,
    [switch]$CleanTestState
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
try {
    Add-Type -AssemblyName PresentationFramework
}
catch {
}

if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
    $VaultRoot = 'C:\Users\18826\Documents\work_doc_ob\Telpo'
}
if ([string]::IsNullOrWhiteSpace($PluginDataPath)) {
    $PluginDataPath = Join-Path $VaultRoot '.obsidian\plugins\obsidian-system-task-notifier\data.json'
}
if ([string]::IsNullOrWhiteSpace($StatePath)) {
    $StatePath = Join-Path $PSScriptRoot 'state.json'
}
if ([string]::IsNullOrWhiteSpace($TodayTodoDir)) {
    $TodayTodoDir = Join-Path $VaultRoot '工作笔记\今日待办'
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $TodayTodoDir '任务提醒运行日志.md'
}
$DebugPath = Join-Path $PSScriptRoot 'debug.log'

function Write-DebugTrace {
    param([Parameter(Mandatory = $true)][string]$Message)
    try {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        [System.IO.File]::AppendAllText($DebugPath, "[$stamp] $Message`r`n", [System.Text.Encoding]::UTF8)
    }
    catch {
    }
}

Write-DebugTrace -Message 'script-start'

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
title: 任务提醒运行日志
tags:
  - 工作笔记
  - 今日待办
  - 提醒
  - 自动化
created: $today
updated: $today
status: 常用
---

# 任务提醒运行日志

## 运行记录

"@
        [System.IO.File]::WriteAllText($LogPath, $initialContent, [System.Text.Encoding]::UTF8)
    }
}

function Write-RunLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    Ensure-MarkdownLog
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    try {
        [System.IO.File]::AppendAllText($LogPath, "- [$stamp] $Message`r`n", [System.Text.Encoding]::UTF8)
        $safePath = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($LogPath))
        Write-DebugTrace -Message "runlog-write ok pathBase64=$safePath message=$Message"
    }
    catch {
        Write-DebugTrace -Message "runlog-write failed reason=$($_.Exception.Message)"
        throw
    }
}

function Load-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()]$DefaultValue
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-DebugTrace -Message "json-missing path=$Path"
        return $DefaultValue
    }

    $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-DebugTrace -Message "json-empty path=$Path"
        return $DefaultValue
    }

    try {
        return ($raw | ConvertFrom-Json)
    }
    catch {
        Write-RunLog -Message "Invalid JSON: $Path reason=$($_.Exception.Message)"
        Write-DebugTrace -Message "json-invalid path=$Path reason=$($_.Exception.Message)"
        return $DefaultValue
    }
}

function Save-State {
    param([Parameter(Mandatory = $true)]$State)
    $dir = Split-Path -Parent $StatePath
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        Ensure-Directory -Path $dir
    }
    $json = $State | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($StatePath, $json, [System.Text.Encoding]::UTF8)
}

function Get-TodayTodoPath {
    $today = Get-Date -Format 'yyyy-MM-dd'
    return Join-Path $TodayTodoDir "$today-今日待办.md"
}

function Get-DayPlannerTasksFromMarkdown {
    $todayFile = Get-TodayTodoPath
    if (-not (Test-Path -LiteralPath $todayFile -PathType Leaf)) {
        return @()
    }

    $raw = Get-Content -Raw -LiteralPath $todayFile
    $normalized = $raw -replace "`r`n", "`n"
    $match = [regex]::Match($normalized, '## Day Planner 今日安排\n\n([\s\S]*?)(?=\n## |$)')
    if (-not $match.Success) {
        return @()
    }

    $lines = $match.Groups[1].Value -split "`n"
    $tasks = New-Object System.Collections.Generic.List[object]
    $lineIndex = 0
    foreach ($line in $lines) {
        $lineIndex++
        $trimmed = $line.Trim()
        if ($trimmed -match '^- \[[ x/\-]\]\s*(\d{2}:\d{2})\s+(.+)$') {
            $time = $matches[1]
            $title = $matches[2]
            $tasks.Add([pscustomobject]@{
                id = "fallback_$time`_$lineIndex"
                planDate = (Get-Date -Format 'yyyy-MM-dd')
                time = $time
                title = $title
                sourceFile = $todayFile
                sourceLine = $lineIndex
                rawText = $trimmed
                priority = Get-TaskPriority -Task ([pscustomobject]@{ title = $title })
                status = 'pending'
                notifyCount = 0
                lastNotifiedAt = ''
                snoozeUntil = ''
            }) | Out-Null
        }
    }
    return @($tasks)
}

function Load-NotificationPlan {
    $pluginData = Load-JsonFile -Path $PluginDataPath -DefaultValue $null
    $markdownTasks = Get-DayPlannerTasksFromMarkdown
    if (@($markdownTasks).Count -gt 0) {
        Write-DebugTrace -Message "plan-from-markdown count=$(@($markdownTasks).Count)"
        return [pscustomobject]@{
            enableToast = if ($null -ne $pluginData -and $pluginData.PSObject.Properties['enableToast']) { [bool]$pluginData.enableToast } else { $true }
            enableSound = if ($null -ne $pluginData -and $pluginData.PSObject.Properties['enableSound']) { [bool]$pluginData.enableSound } else { $true }
            enableFallbackPopup = if ($null -ne $pluginData -and $pluginData.PSObject.Properties['enableFallbackPopup']) { [bool]$pluginData.enableFallbackPopup } else { $true }
            repeatMinutes = if ($null -ne $pluginData -and $pluginData.PSObject.Properties['repeatMinutes'] -and @($pluginData.repeatMinutes).Count -gt 0) { @($pluginData.repeatMinutes) } else { @(2, 5, 10) }
            maxNotifyCount = if ($null -ne $pluginData -and $pluginData.PSObject.Properties['maxNotifyCount']) { [int]$pluginData.maxNotifyCount } else { 4 }
            lastRefreshAt = if ($null -ne $pluginData -and $pluginData.PSObject.Properties['lastRefreshAt']) { [string]$pluginData.lastRefreshAt } else { '' }
            lastPlanDate = (Get-Date -Format 'yyyy-MM-dd')
            tasks = $markdownTasks
        }
    }

    if ($null -ne $pluginData -and $pluginData.PSObject.Properties['tasks']) {
        $rawTasks = $pluginData.tasks
        $rawType = if ($null -ne $rawTasks) { $rawTasks.GetType().FullName } else { '<null>' }
        $taskList = @($rawTasks)
        Write-DebugTrace -Message "plan-from-plugin rawType=$rawType count=$($taskList.Count)"
        if ($taskList.Count -gt 0) {
            $pluginData.tasks = $taskList
            return $pluginData
        }
    }
    else {
        Write-DebugTrace -Message 'plan-from-plugin missing-or-no-tasks'
    }

    Write-DebugTrace -Message 'plan-empty count=0'
    return [pscustomobject]@{
        enableToast = $true
        enableSound = $true
        enableFallbackPopup = $true
        repeatMinutes = @(2, 5, 10)
        maxNotifyCount = 4
        lastRefreshAt = ''
        lastPlanDate = (Get-Date -Format 'yyyy-MM-dd')
        tasks = @()
    }
}

function Load-State {
    $default = [pscustomobject]@{
        tasks = @{}
        lastRunAt = ''
    }
    $state = Load-JsonFile -Path $StatePath -DefaultValue $default
    if (-not $state.PSObject.Properties['tasks']) {
        $state | Add-Member -NotePropertyName tasks -NotePropertyValue @{}
    }
    return $state
}

function Get-TaskStateKey {
    param([Parameter(Mandatory = $true)]$Task)

    $idText = [string]$Task.id
    if ([string]::IsNullOrWhiteSpace($idText)) {
        return [guid]::NewGuid().ToString('N')
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($idText)
    $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $hash = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
    return "task_$hash"
}

function Get-TimeInfo {
    param([Parameter(Mandatory = $true)][string]$Time)
    if ($Time -notmatch '^(\d{2}):(\d{2})$') {
        return $null
    }
    $hours = [int]$matches[1]
    $minutes = [int]$matches[2]
    return [pscustomobject]@{
        TotalMinutes = ($hours * 60) + $minutes
        Text = $Time
    }
}

function Get-TaskPriority {
    param([Parameter(Mandatory = $true)]$Task)

    $priority = ''
    if ($Task.PSObject.Properties.Name -contains 'priority') {
        $priority = [string]$Task.priority
    }
    if (-not [string]::IsNullOrWhiteSpace($priority)) {
        return $priority
    }

    $title = if ($Task.PSObject.Properties.Name -contains 'title') { [string]$Task.title } else { '' }
    if ($title -match '测试|test') {
        return 'test'
    }
    if ($title -match '重要紧急') {
        return 'important-urgent'
    }
    if ($title -match '重要不紧急') {
        return 'important-not-urgent'
    }
    if ($title -match '持续') {
        return 'recurring'
    }
    return 'normal'
}

function Get-PriorityVisualSpec {
    param([Parameter(Mandatory = $true)][string]$Priority)

    switch ($Priority) {
        'important-urgent' {
            return [pscustomobject]@{
                Priority = $Priority
                HeaderBg = '#c62828'
                HeaderColor = '#fff8f3'
                BorderColor = '#ff7043'
                BodyBg = '#fff1eb'
                BodyAccent = '#bf360c'
                BadgeText = '重要紧急'
                BadgeBg = '#ffb300'
                BadgeColor = '#4e1a00'
                PriorityOrder = 0
                DisplayBias = 0
            }
        }
        'important-not-urgent' {
            return [pscustomobject]@{
                Priority = $Priority
                HeaderBg = '#f9a825'
                HeaderColor = '#3e2723'
                BorderColor = '#f57f17'
                BodyBg = '#fff8e1'
                BodyAccent = '#8d6e63'
                BadgeText = '重要不紧急'
                BadgeBg = '#ffe082'
                BadgeColor = '#5d4037'
                PriorityOrder = 1
                DisplayBias = 0
            }
        }
        'recurring' {
            return [pscustomobject]@{
                Priority = $Priority
                HeaderBg = '#1565c0'
                HeaderColor = '#eef7ff'
                BorderColor = '#26c6da'
                BodyBg = '#eef8ff'
                BodyAccent = '#0d47a1'
                BadgeText = '持续任务'
                BadgeBg = '#80deea'
                BadgeColor = '#004d40'
                PriorityOrder = 3
                DisplayBias = 2
            }
        }
        'fallback' {
            return [pscustomobject]@{
                Priority = $Priority
                HeaderBg = '#6a1b9a'
                HeaderColor = '#faf5ff'
                BorderColor = '#ba68c8'
                BodyBg = '#f7f0fb'
                BodyAccent = '#6a1b9a'
                BadgeText = '兜底提醒'
                BadgeBg = '#e1bee7'
                BadgeColor = '#4a148c'
                PriorityOrder = 4
                DisplayBias = 3
            }
        }
        'test' {
            return [pscustomobject]@{
                Priority = $Priority
                HeaderBg = '#455a64'
                HeaderColor = '#f6fbff'
                BorderColor = '#90a4ae'
                BodyBg = '#f4f7f8'
                BodyAccent = '#37474f'
                BadgeText = '测试提醒'
                BadgeBg = '#cfd8dc'
                BadgeColor = '#263238'
                PriorityOrder = 5
                DisplayBias = 5
            }
        }
        default {
            return [pscustomobject]@{
                Priority = 'normal'
                HeaderBg = '#fff7cc'
                HeaderColor = '#7a1f00'
                BorderColor = '#eadf9b'
                BodyBg = '#fffdf2'
                BodyAccent = '#7a1f00'
                BadgeText = '普通任务'
                BadgeBg = '#fff1a8'
                BadgeColor = '#6d4c41'
                PriorityOrder = 2
                DisplayBias = 1
            }
        }
    }
}

function Get-TaskDisplayRank {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$TaskState,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $taskTime = Get-TimeInfo -Time ([string]$Task.time)
    $priority = Get-TaskPriority -Task $Task
    $visualSpec = Get-PriorityVisualSpec -Priority $priority
    $currentMinutes = ($Now.Hour * 60) + $Now.Minute
    $taskMinutes = if ($null -ne $taskTime) { [int]$taskTime.TotalMinutes } else { 9999 }
    $overdueMinutes = [Math]::Max(0, $currentMinutes - $taskMinutes)
    $alreadyNotified = -not [string]::IsNullOrWhiteSpace([string]$TaskState.lastNotifiedAt)

    $freshnessBucket = if ($alreadyNotified) { 1 } else { 0 }
    $overdueBucket = if ($overdueMinutes -ge 120) { 2 } elseif ($overdueMinutes -ge 30) { 1 } else { 0 }
    if ($priority -eq 'test') {
        $freshnessBucket = 9
    }

    return [pscustomobject]@{
        Priority = $priority
        PriorityOrder = [int]$visualSpec.PriorityOrder
        DisplayBias = [int]$visualSpec.DisplayBias
        FreshnessBucket = $freshnessBucket
        OverdueBucket = $overdueBucket
        OverdueMinutes = $overdueMinutes
        TimeMinutes = $taskMinutes
    }
}

function Remove-StaleTaskState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][datetime]$Now,
        [switch]$Force
    )

    $activeTaskIds = @{}
    foreach ($planTask in @($Plan.tasks)) {
        $activeTaskIds[[string]$planTask.id] = $true
    }

    $keysToRemove = New-Object System.Collections.Generic.List[string]
    foreach ($stateKey in @($State.tasks.Keys)) {
        $entry = $State.tasks[$stateKey]
        $taskId = if ($entry.PSObject.Properties.Name -contains 'taskId' -and $entry.taskId) { [string]$entry.taskId } else { [string]$stateKey }
        $title = if ($entry.PSObject.Properties.Name -contains 'title' -and $entry.title) { [string]$entry.title } else { '' }
        $isTestRecord = ($taskId -match '_test_' -or $stateKey -match '_test_' -or $title -match '测试')
        if (-not $isTestRecord) {
            continue
        }
        if ($activeTaskIds.ContainsKey($taskId)) {
            continue
        }

        if ($Force) {
            $keysToRemove.Add($stateKey) | Out-Null
            continue
        }

        $referenceTime = $null
        foreach ($candidate in @([string]$entry.lastNotifiedAt, [string]$State.lastRunAt)) {
            if ([string]::IsNullOrWhiteSpace($candidate)) {
                continue
            }
            try {
                $referenceTime = [datetime]$candidate
                break
            }
            catch {
            }
        }

        if ($null -eq $referenceTime -or $referenceTime -le $Now.AddDays(-1)) {
            $keysToRemove.Add($stateKey) | Out-Null
        }
    }

    foreach ($stateKey in $keysToRemove) {
        $State.tasks.Remove($stateKey)
    }
    return $keysToRemove.Count
}

function Test-TaskCompleted {
    param([Parameter(Mandatory = $true)]$Task)

    $rawText = if ($Task.PSObject.Properties.Name -contains 'rawText') { [string]$Task.rawText } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($rawText)) {
        return ($rawText -match '^\s*-\s*\[[xX]\]')
    }

    if ($Task.PSObject.Properties.Name -contains 'status') {
        return ([string]$Task.status -eq 'done')
    }

    return $false
}

function Get-TaskSummaryLine {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [int]$MaxTitleLength = 26
    )

    $timeText = if ($Task.PSObject.Properties.Name -contains 'time' -and -not [string]::IsNullOrWhiteSpace([string]$Task.time)) { [string]$Task.time } else { '--:--' }
    $titleText = if ($Task.PSObject.Properties.Name -contains 'title') { [string]$Task.title } else { '' }
    if ($MaxTitleLength -gt 0 -and $titleText.Length -gt $MaxTitleLength) {
        $titleText = $titleText.Substring(0, $MaxTitleLength) + '...'
    }
    return "[$timeText] $titleText"
}

function Get-RemainingOpenTasksForToday {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)]$CurrentTask,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $todayText = $Now.ToString('yyyy-MM-dd')
    $remainingTasks = New-Object System.Collections.Generic.List[object]
    foreach ($task in @($Plan.tasks)) {
        if ($task.PSObject.Properties.Name -contains 'id' -and [string]$task.id -eq [string]$CurrentTask.id) {
            continue
        }

        $taskPlanDate = if ($task.PSObject.Properties.Name -contains 'planDate') { [string]$task.planDate } else { $todayText }
        if (-not [string]::IsNullOrWhiteSpace($taskPlanDate) -and $taskPlanDate -ne $todayText) {
            continue
        }

        if (Test-TaskCompleted -Task $task) {
            continue
        }

        $remainingTasks.Add($task) | Out-Null
    }

    return @(
        $remainingTasks | Sort-Object `
            @{ Expression = {
                $timeInfo = Get-TimeInfo -Time ([string]$_.time)
                if ($null -ne $timeInfo) { [int]$timeInfo.TotalMinutes } else { 9999 }
            } },
            @{ Expression = { [int](Get-PriorityVisualSpec -Priority (Get-TaskPriority -Task $_)).PriorityOrder } },
            @{ Expression = { [string]$_.title } }
    )
}

function Test-TaskOverdue {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $timeText = if ($Task.PSObject.Properties.Name -contains 'time') { [string]$Task.time } else { '' }
    $timeInfo = Get-TimeInfo -Time $timeText
    if ($null -eq $timeInfo) {
        return $false
    }

    $currentMinutes = ($Now.Hour * 60) + $Now.Minute
    return ($currentMinutes -gt [int]$timeInfo.TotalMinutes)
}

function Get-GardenProgressState {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $todayText = $Now.ToString('yyyy-MM-dd')
    $todayTasks = New-Object System.Collections.Generic.List[object]
    foreach ($task in @($Plan.tasks)) {
        $taskPlanDate = if ($task.PSObject.Properties.Name -contains 'planDate') { [string]$task.planDate } else { $todayText }
        if (-not [string]::IsNullOrWhiteSpace($taskPlanDate) -and $taskPlanDate -ne $todayText) {
            continue
        }
        $todayTasks.Add($task) | Out-Null
    }

    $totalTasks = @($todayTasks).Count
    $completedTasks = 0
    foreach ($task in @($todayTasks)) {
        if (Test-TaskCompleted -Task $task) {
            $completedTasks++
        }
    }
    $remainingTasks = [Math]::Max(0, $totalTasks - $completedTasks)
    $completionRate = if ($totalTasks -gt 0) { [double]$completedTasks / [double]$totalTasks } else { 0.0 }

    $plantKind = if ($totalTasks -le 3) {
        'sprout'
    }
    elseif ($totalTasks -le 6) {
        'tulip'
    }
    else {
        'blossom'
    }

    $growthStage = if ($totalTasks -le 0) {
        0
    }
    elseif ($completionRate -ge 1.0) {
        5
    }
    elseif ($completionRate -ge 0.76) {
        4
    }
    elseif ($completionRate -ge 0.51) {
        3
    }
    elseif ($completionRate -ge 0.26) {
        2
    }
    elseif ($completionRate -gt 0.0) {
        1
    }
    else {
        0
    }

    return [pscustomobject]@{
        TotalTasks = $totalTasks
        CompletedTasks = $completedTasks
        RemainingTasks = $remainingTasks
        CompletionRate = $completionRate
        PlantKind = $plantKind
        GrowthStage = $growthStage
    }
}

function Format-RemainingTasksSummary {
    param(
        [Parameter(Mandatory = $true)]$CurrentTask,
        [Parameter(Mandatory = $true)]$RemainingTasks,
        [Parameter(Mandatory = $true)][datetime]$Now,
        [int]$MaxItems = 5
    )

    $overdueStartMarker = '__OVERDUE_START__'
    $overdueEndMarker = '__OVERDUE_END__'
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('当前任务：') | Out-Null
    $lines.Add((Get-TaskSummaryLine -Task $CurrentTask -MaxTitleLength 0)) | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('当天剩余未完成任务：') | Out-Null

    $remainingCount = @($RemainingTasks).Count
    if ($remainingCount -le 0) {
        $lines.Add('今天其余任务已完成。') | Out-Null
        return ($lines -join "`n")
    }

    $displayCount = [Math]::Min($MaxItems, $remainingCount)
    for ($i = 0; $i -lt $displayCount; $i++) {
        $task = @($RemainingTasks)[$i]
        $line = "• $(Get-TaskSummaryLine -Task $task)"
        if (Test-TaskOverdue -Task $task -Now $Now) {
            $line = "$overdueStartMarker$line$overdueEndMarker"
        }
        $lines.Add($line) | Out-Null
    }

    if ($remainingCount -gt $displayCount) {
        $lines.Add("... 另有 $($remainingCount - $displayCount) 项未显示") | Out-Null
    }

    return ($lines -join "`n")
}

function Should-NotifyTask {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$TaskState,
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $taskTime = Get-TimeInfo -Time ([string]$Task.time)
    if ($null -eq $taskTime) {
        return $false
    }

    $currentMinutes = ($Now.Hour * 60) + $Now.Minute
    if ($currentMinutes -lt $taskTime.TotalMinutes) {
        return $false
    }

    if ($TaskState.status -eq 'done') {
        return $false
    }

    if ($TaskState.snoozeUntil) {
        try {
            $snoozeUntil = [datetime]$TaskState.snoozeUntil
            if ($Now -lt $snoozeUntil) {
                return $false
            }
        }
        catch {
        }
    }

    $maxNotifyCount = if ($Plan.PSObject.Properties['maxNotifyCount']) { [int]$Plan.maxNotifyCount } else { 4 }
    $notifyCount = if ($TaskState.notifyCount) { [int]$TaskState.notifyCount } else { 0 }
    if ($notifyCount -ge $maxNotifyCount) {
        return $false
    }

    if (-not $TaskState.lastNotifiedAt) {
        return $true
    }

    try {
        $last = [datetime]$TaskState.lastNotifiedAt
        $repeatMinutes = @($Plan.repeatMinutes)
        if ($notifyCount -lt $repeatMinutes.Count) {
            $delay = [int]$repeatMinutes[$notifyCount]
        }
        else {
            $delay = [int]$repeatMinutes[-1]
        }
        return $Now -ge $last.AddMinutes($delay)
    }
    catch {
        return $true
    }
}

function Play-AlertSound {
    try {
        [System.Media.SystemSounds]::Exclamation.Play()
        Start-Sleep -Milliseconds 250
        [System.Media.SystemSounds]::Exclamation.Play()
    }
    catch {
    }
}

function Convert-ToHtmlEntityString {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ''
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Text.ToCharArray()) {
        $code = [int][char]$char
        switch ($char) {
            '&' { [void]$builder.Append('&amp;') }
            '<' { [void]$builder.Append('&lt;') }
            '>' { [void]$builder.Append('&gt;') }
            '"' { [void]$builder.Append('&quot;') }
            "'" { [void]$builder.Append('&#39;') }
            "`r" { }
            "`n" { [void]$builder.Append('<br/>') }
            default {
                if ($code -lt 128) {
                    [void]$builder.Append($char)
                }
                else {
                    [void]$builder.Append('&#').Append($code).Append(';')
                }
            }
        }
    }
    return $builder.ToString()
}

function Close-ExistingTaskPopups {
    param([Parameter(Mandatory = $true)][string]$PopupPath)

    $closedCount = 0
    try {
        $escapedPath = $PopupPath.Replace("'", "''")
        $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'mshta.exe'" | Where-Object {
            $_.CommandLine -and $_.CommandLine -like "*$escapedPath*"
        })

        foreach ($processInfo in $processes) {
            try {
                Stop-Process -Id ([int]$processInfo.ProcessId) -Force -ErrorAction Stop
                $closedCount++
                Write-DebugTrace -Message "fallback-popup closed-old-mshta pid=$($processInfo.ProcessId)"
            }
            catch {
                Write-DebugTrace -Message "fallback-popup close-old-mshta-failed pid=$($processInfo.ProcessId) reason=$($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-DebugTrace -Message "fallback-popup close-scan-failed reason=$($_.Exception.Message)"
    }

    return $closedCount
}

function Show-FallbackPopup {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)]$VisualSpec
    )

    try {
        $tempDir = Join-Path $env:TEMP 'obsidian-task-notifier'
        Ensure-Directory -Path $tempDir

        $htaPath = Join-Path $tempDir 'task-popup.hta'
        $closedPopupCount = Close-ExistingTaskPopups -PopupPath $htaPath
        $iconPath = Join-Path $PSScriptRoot 'task-notifier.ico'
        $safeIconPath = Convert-ToHtmlEntityString -Text $iconPath
        $safeTitle = Convert-ToHtmlEntityString -Text $Title
        $safeMessage = Convert-ToHtmlEntityString -Text $Message
        $safeButtonText = Convert-ToHtmlEntityString -Text '知道了'
        $safeHeaderBg = [string]$VisualSpec.HeaderBg
        $safeHeaderColor = [string]$VisualSpec.HeaderColor
        $safeBorderColor = [string]$VisualSpec.BorderColor
        $safeBodyBg = [string]$VisualSpec.BodyBg
        $safeBodyAccent = [string]$VisualSpec.BodyAccent
        $safeBadgeText = Convert-ToHtmlEntityString -Text ([string]$VisualSpec.BadgeText)
        $safeBadgeBg = [string]$VisualSpec.BadgeBg
        $safeBadgeColor = [string]$VisualSpec.BadgeColor
        $safeOverdueStartMarker = '__OVERDUE_START__'
        $safeOverdueEndMarker = '__OVERDUE_END__'
        $safeOverduePrefix = '<span style="color:#8b1e3f;">'
        $safeOverdueSuffix = '</span>'
        $safeMessage = $safeMessage.Replace($safeOverdueStartMarker, $safeOverduePrefix).Replace($safeOverdueEndMarker, $safeOverdueSuffix)
        $badgeDisplay = if ([string]::IsNullOrWhiteSpace([string]$VisualSpec.BadgeText)) { 'none' } else { 'inline-block' }
        $hta = @"
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=9" />
<meta charset="utf-8" />
<title>__TITLE__</title>
<HTA:APPLICATION APPLICATIONNAME="ObsidianTaskNotifier" ICON="__ICON_PATH__" BORDER="thin" CAPTION="yes" SHOWINTASKBAR="yes" SINGLEINSTANCE="yes" SYSMENU="yes" WINDOWSTATE="normal" />
<style type="text/css">
#headerMascotZone { position:absolute; right:10px; top:4px; width:118px; height:74px; overflow:hidden; }
#mascotWrap { position:absolute; left:26px; top:10px; width:72px; height:52px; }
#mascotMood { display:none; position:absolute; left:0; top:46px; padding:2px 8px; background:#fff5d6; border:1px solid #d8c197; color:#6b5245; border-radius:12px; font-size:12px; line-height:1.2; white-space:nowrap; }
.seaLionBody { position:absolute; left:11px; top:24px; width:50px; height:22px; background:#8fa2b2; border:2px solid #506170; border-radius:24px 24px 18px 18px; }
.seaLionBelly { position:absolute; left:22px; top:30px; width:26px; height:10px; background:#edf3f7; border-radius:10px; }
.seaLionHead { position:absolute; left:18px; top:2px; width:34px; height:28px; background:#99acbb; border:2px solid #506170; border-radius:18px 18px 16px 16px; }
.seaLionNose { position:absolute; left:31px; top:15px; width:8px; height:6px; background:#3e4a54; border-radius:6px; }
.seaLionMouth { position:absolute; left:28px; top:20px; width:14px; height:6px; border-bottom:2px solid #6a4f43; border-radius:0 0 10px 10px; }
.seaLionEye { position:absolute; width:4px; height:6px; background:#2d1b15; border-radius:4px; top:11px; }
#seaLionEyeLeft { left:26px; }
#seaLionEyeRight { left:40px; }
.seaLionFlipper { position:absolute; width:14px; height:9px; background:#7f93a3; border:2px solid #506170; border-radius:12px 12px 8px 8px; top:35px; }
#seaLionFlipperLeft { left:8px; }
#seaLionFlipperRight { left:49px; }
.seaLionWhisker { position:absolute; width:12px; height:1px; background:#6f584e; top:18px; }
#seaLionWhiskerLeft { left:16px; }
#seaLionWhiskerRight { left:44px; }
</style>
<script language="javascript">
var autoCloseTimer = null;
var mascotTimer = null;
var mascotMoodTimer = null;
var mascotBaseLeft = 26;
var mascotBaseTop = 10;
function fitWindow() {
  try {
    var minWidth = 760;
    var minHeight = 320;
    var maxHeight = Math.max(minHeight, Math.floor(screen.availHeight * 0.86));
    var chromePadding = 90;
    var messageBox = document.getElementById('messageBox');
    var headerBox = document.getElementById('headerBox');
    var footerBox = document.getElementById('footerBox');
    var headerHeight = headerBox ? headerBox.offsetHeight : 72;
    var footerHeight = footerBox ? footerBox.offsetHeight : 76;
    var availableMessageHeight = Math.max(160, maxHeight - headerHeight - footerHeight - chromePadding);
    if (messageBox) {
      messageBox.style.height = 'auto';
      var desiredHeight = Math.max(140, Math.min(messageBox.scrollHeight + 20, availableMessageHeight));
      messageBox.style.height = desiredHeight + 'px';
      messageBox.style.maxHeight = availableMessageHeight + 'px';
      if (messageBox.scrollHeight > desiredHeight) {
        messageBox.style.overflowY = 'auto';
      }
      else {
        messageBox.style.overflowY = 'hidden';
      }
    }

    var body = document.body;
    var computedHeight = body ? Math.max(minHeight, Math.min(body.scrollHeight + 40, maxHeight)) : minHeight;
    window.resizeTo(minWidth, computedHeight);
    window.moveTo(Math.max(0, (screen.availWidth - minWidth) / 2), Math.max(0, (screen.availHeight - computedHeight) / 2));
  } catch (e) {}
}
function setMascotPosition(dx, dy) {
  var mascotWrap = document.getElementById('mascotWrap');
  if (!mascotWrap) { return; }
  mascotWrap.style.left = (mascotBaseLeft + dx) + 'px';
  mascotWrap.style.top = (mascotBaseTop + dy) + 'px';
}
function setSeaLionEyes(closed) {
  var leftEye = document.getElementById('seaLionEyeLeft');
  var rightEye = document.getElementById('seaLionEyeRight');
  var eyeHeight = closed ? 2 : 6;
  var eyeTop = closed ? 14 : 11;
  if (leftEye) {
    leftEye.style.height = eyeHeight + 'px';
    leftEye.style.top = eyeTop + 'px';
  }
  if (rightEye) {
    rightEye.style.height = eyeHeight + 'px';
    rightEye.style.top = eyeTop + 'px';
  }
}
function setRightFlipper(active) {
  var flipper = document.getElementById('seaLionFlipperRight');
  if (!flipper) { return; }
  if (active) {
    flipper.style.left = '52px';
    flipper.style.top = '25px';
    flipper.style.width = '12px';
    flipper.style.height = '12px';
  }
  else {
    flipper.style.left = '49px';
    flipper.style.top = '35px';
    flipper.style.width = '14px';
    flipper.style.height = '9px';
  }
}
function showMascotMood(text) {
  var mood = document.getElementById('mascotMood');
  if (!mood || !text) { return; }
  mood.innerHTML = text;
  mood.style.display = 'block';
  if (mascotMoodTimer) {
    window.clearTimeout(mascotMoodTimer);
  }
  mascotMoodTimer = window.setTimeout(function() {
    mood.style.display = 'none';
  }, 1100);
}
function resetMascotPose() {
  setMascotPosition(0, 0);
  setSeaLionEyes(false);
  setRightFlipper(false);
}
function scheduleMascotAction() {
  if (mascotTimer) {
    window.clearTimeout(mascotTimer);
  }
  mascotTimer = window.setTimeout(runMascotAction, 2600 + Math.floor(Math.random() * 2600));
}
function runMascotAction() {
  var roll = Math.random();
  resetMascotPose();
  if (roll < 0.35) {
    var dx = -6 + Math.floor(Math.random() * 13);
    var dy = Math.floor(Math.random() * 5) - 2;
    setMascotPosition(dx, dy);
    if (Math.random() < 0.35) {
      showMascotMood('加油');
    }
    window.setTimeout(function() {
      resetMascotPose();
      scheduleMascotAction();
    }, 720);
    return;
  }
  if (roll < 0.60) {
    setSeaLionEyes(true);
    window.setTimeout(function() {
      setSeaLionEyes(false);
      if (Math.random() < 0.45) {
        showMascotMood('稳住');
      }
      scheduleMascotAction();
    }, 180);
    return;
  }
  if (roll < 0.84) {
    setMascotPosition(-10, -1);
    if (Math.random() < 0.70) {
      showMascotMood('冲呀');
    }
    window.setTimeout(function() {
      resetMascotPose();
      scheduleMascotAction();
    }, 650);
    return;
  }
  setMascotPosition(4, -5);
  setRightFlipper(true);
  showMascotMood('继续');
  window.setTimeout(function() {
    resetMascotPose();
    scheduleMascotAction();
  }, 760);
}
function initMascot() {
  resetMascotPose();
  scheduleMascotAction();
}
function init() {
  try {
    fitWindow();
    window.setTimeout(fitWindow, 60);
    initMascot();
    if (autoCloseTimer) {
      window.clearTimeout(autoCloseTimer);
    }
    autoCloseTimer = window.setTimeout(closeWindow, 20 * 60 * 1000);
    window.focus();
  } catch (e) {}
}
function closeWindow() {
  try {
    if (autoCloseTimer) { window.clearTimeout(autoCloseTimer); }
    if (mascotTimer) { window.clearTimeout(mascotTimer); }
    if (mascotMoodTimer) { window.clearTimeout(mascotMoodTimer); }
  } catch (e) {}
  window.close();
}
</script>
</head>
<body onload="init()" style="font-family:'Microsoft YaHei UI','Microsoft YaHei',sans-serif;background:__BODY_BG__;margin:0;padding:0;overflow:hidden;border:4px solid __BORDER_COLOR__;">
  <div id="headerBox" style="position:relative; padding:18px 146px 18px 22px; border-bottom:1px solid __BORDER_COLOR__; background:__HEADER_BG__; font-size:24px; font-weight:700; color:__HEADER_COLOR__;">
    <span>__TITLE__</span>
    <span style="display:__BADGE_DISPLAY__; margin-left:14px; padding:4px 12px; border-radius:999px; background:__BADGE_BG__; color:__BADGE_COLOR__; font-size:14px; vertical-align:middle;">__BADGE__</span>
    <div id="headerMascotZone">
      <div id="mascotWrap">
        <div class="seaLionBody"></div>
        <div class="seaLionBelly"></div>
        <div class="seaLionHead"></div>
        <div id="seaLionEyeLeft" class="seaLionEye"></div>
        <div id="seaLionEyeRight" class="seaLionEye"></div>
        <div class="seaLionNose"></div>
        <div class="seaLionMouth"></div>
        <div id="seaLionFlipperLeft" class="seaLionFlipper"></div>
        <div id="seaLionFlipperRight" class="seaLionFlipper"></div>
        <div id="seaLionWhiskerLeft" class="seaLionWhisker"></div>
        <div id="seaLionWhiskerRight" class="seaLionWhisker"></div>
      </div>
      <div id="mascotMood">加油</div>
    </div>
  </div>
  <div id="messageBox" style="padding:26px 24px 10px 24px; font-size:24px; line-height:1.6; color:__BODY_ACCENT__; font-weight:700; word-break:break-all; min-height:140px; max-height:520px; overflow:auto; box-sizing:border-box;">__MESSAGE__</div>
  <div id="footerBox" style="text-align:center; padding:18px 0 20px 0;">
    <button onclick="closeWindow()" style="font-size:18px; padding:8px 28px; font-family:'Microsoft YaHei UI','Microsoft YaHei',sans-serif;">__BUTTON__</button>
  </div>
</body>
</html>
"@
        $hta = $hta.Replace('__TITLE__', $safeTitle).Replace('__MESSAGE__', $safeMessage).Replace('__BUTTON__', $safeButtonText).Replace('__HEADER_BG__', $safeHeaderBg).Replace('__HEADER_COLOR__', $safeHeaderColor).Replace('__BORDER_COLOR__', $safeBorderColor).Replace('__BODY_BG__', $safeBodyBg).Replace('__BODY_ACCENT__', $safeBodyAccent).Replace('__BADGE__', $safeBadgeText).Replace('__BADGE_BG__', $safeBadgeBg).Replace('__BADGE_COLOR__', $safeBadgeColor).Replace('__BADGE_DISPLAY__', $badgeDisplay).Replace('__ICON_PATH__', $safeIconPath)
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($htaPath, $hta, $utf8Bom)

        $mshtaExe = Join-Path $env:SystemRoot 'System32\mshta.exe'
        $process = Start-Process -FilePath $mshtaExe -ArgumentList @($htaPath) -PassThru
        Write-DebugTrace -Message "fallback-popup launched-mshta pid=$($process.Id) path=$htaPath priority=$($VisualSpec.Priority) closedOld=$closedPopupCount"
        return $true
    }
    catch {
        Write-DebugTrace -Message "fallback-popup failed reason=$($_.Exception.Message)"
        return $false
    }
}

function Send-SystemTaskNotification {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)]$DisplayRank,
        [Parameter(Mandatory = $true)][string]$PopupMessage,
        [int]$RemainingTaskCount = 0,
        [int]$RemainingDisplayCount = 0
    )

    $priority = Get-TaskPriority -Task $Task
    $visualSpec = Get-PriorityVisualSpec -Priority $priority
    $title = '当前任务提醒'
    $taskTimeText = [string]$Task.time
    $taskTitleText = [string]$Task.title
    $message = "[$taskTimeText] $taskTitleText"
    $fullMessage = $message
    $usedFallback = $false
    $toastShown = $false
    $popupLaunched = $false

    try {
        if ($Plan.enableToast) {
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null
            $toastTitle = switch ($priority) {
                'important-urgent' { '【重要紧急】当前任务提醒' }
                'important-not-urgent' { '【重要】当前任务提醒' }
                'recurring' { '【持续任务】当前任务提醒' }
                'test' { '【测试】当前任务提醒' }
                default { $title }
            }
            $toastPrefix = switch ($priority) {
                'important-urgent' { '请立即处理：' }
                'important-not-urgent' { '优先安排：' }
                'recurring' { '保持节奏：' }
                'test' { '验证提醒链路：' }
                default { '' }
            }
            $toastBody = if ([string]::IsNullOrWhiteSpace($toastPrefix)) { $fullMessage } else { "$toastPrefix$fullMessage" }
            $escapedTitle = [System.Security.SecurityElement]::Escape($toastTitle)
            $escapedMessage = [System.Security.SecurityElement]::Escape($toastBody)
            $xmlText = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedTitle</text>
      <text>$escapedMessage</text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Looping.Alarm2"/>
</toast>
"@
            $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $xml.LoadXml($xmlText)
            $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Obsidian Task Notifier').Show($toast)
            $toastShown = $true
            Write-DebugTrace -Message "toast-show invoked priority=$priority"
        }
        else {
            $usedFallback = $true
            Write-DebugTrace -Message 'toast-disabled use-fallback'
        }
    }
    catch {
        $usedFallback = $true
        Write-DebugTrace -Message "toast-failed reason=$($_.Exception.Message)"
        Write-RunLog -Message "toast failed title=$($Task.title) reason=$($_.Exception.Message)"
    }

    if ($Plan.enableSound) {
        Play-AlertSound
    }

    if ($Plan.enableFallbackPopup) {
        $usedFallback = $true
        $popupLaunched = Show-FallbackPopup -Title $title -Message $PopupMessage -VisualSpec $visualSpec
    }

    Write-RunLog -Message "notify time=$($Task.time) title=$($Task.title) priority=$priority displayOrder=$($DisplayRank.PriorityOrder)/$($DisplayRank.FreshnessBucket)/$($DisplayRank.OverdueBucket) remainingTotal=$RemainingTaskCount remainingShown=$RemainingDisplayCount fallback=$usedFallback toastShown=$toastShown popupLaunched=$popupLaunched"
}

function Update-TaskState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $taskKey = Get-TaskStateKey -Task $Task
    if (-not $State.tasks.ContainsKey($taskKey)) {
        $State.tasks[$taskKey] = @{}
    }

    $current = $State.tasks[$taskKey]
    $notifyCount = if ($current.notifyCount) { [int]$current.notifyCount } else { 0 }
    $current.notifyCount = $notifyCount + 1
    $current.lastNotifiedAt = $Now.ToString('o')
    $current.status = 'notified'
    $current.taskId = [string]$Task.id
    $current.title = [string]$Task.title
    $current.time = [string]$Task.time
    $State.tasks[$taskKey] = $current
}

function Ensure-StateShape {
    param([Parameter(Mandatory = $true)]$State)
    if ($State.tasks -isnot [hashtable]) {
        $table = @{}
        foreach ($prop in $State.tasks.PSObject.Properties) {
            $table[$prop.Name] = $prop.Value
        }
        $State.tasks = $table
    }
}

function Invoke-NotifierIteration {
    $plan = Load-NotificationPlan
    $state = Load-State
    Ensure-StateShape -State $state
    $now = Get-Date
    $taskCount = @($plan.tasks).Count
    $cleanedStateCount = Remove-StaleTaskState -State $state -Plan $plan -Now $now
    Write-DebugTrace -Message "iteration now=$($now.ToString('o')) tasks=$taskCount cleanedState=$cleanedStateCount"

    $dueTasks = New-Object System.Collections.Generic.List[object]
    foreach ($task in @($plan.tasks)) {
        $taskKey = Get-TaskStateKey -Task $task
        if (-not $state.tasks.ContainsKey($taskKey)) {
            $state.tasks[$taskKey] = @{ notifyCount = 0; lastNotifiedAt = ''; status = 'pending'; snoozeUntil = ''; taskId = [string]$task.id; title = [string]$task.title; time = [string]$task.time }
        }
        $taskState = $state.tasks[$taskKey]
        $shouldNotify = Should-NotifyTask -Task $task -TaskState $taskState -Plan $plan -Now $now
        Write-DebugTrace -Message "task-check id=$($task.id) key=$taskKey time=$($task.time) priority=$(Get-TaskPriority -Task $task) shouldNotify=$shouldNotify"
        if ($shouldNotify) {
            $displayRank = Get-TaskDisplayRank -Task $task -TaskState $taskState -Now $now
            $remainingTasks = Get-RemainingOpenTasksForToday -Plan $plan -CurrentTask $task -Now $now
            $remainingSummary = Format-RemainingTasksSummary -CurrentTask $task -RemainingTasks $remainingTasks -Now $now
            $dueTasks.Add([pscustomobject]@{
                Task = $task
                TaskState = $taskState
                DisplayRank = $displayRank
                RemainingTasks = @($remainingTasks)
                RemainingSummary = $remainingSummary
            }) | Out-Null
        }
    }

    foreach ($entry in @($dueTasks | Sort-Object @{ Expression = { $_.DisplayRank.PriorityOrder } }, @{ Expression = { $_.DisplayRank.FreshnessBucket } }, @{ Expression = { $_.DisplayRank.OverdueBucket } }, @{ Expression = { $_.DisplayRank.DisplayBias } }, @{ Expression = { $_.DisplayRank.TimeMinutes } })) {
        Write-DebugTrace -Message "notify-order id=$($entry.Task.id) priority=$($entry.DisplayRank.Priority) rank=$($entry.DisplayRank.PriorityOrder)/$($entry.DisplayRank.FreshnessBucket)/$($entry.DisplayRank.OverdueBucket)/$($entry.DisplayRank.DisplayBias) remaining=$(@($entry.RemainingTasks).Count)"
        Send-SystemTaskNotification -Task $entry.Task -Plan $plan -DisplayRank $entry.DisplayRank -PopupMessage $entry.RemainingSummary -RemainingTaskCount @($entry.RemainingTasks).Count -RemainingDisplayCount ([Math]::Min(5, @($entry.RemainingTasks).Count))
        Update-TaskState -State $state -Task $entry.Task -Now $now
    }

    $state.lastRunAt = $now.ToString('o')
    Save-State -State $state
}

function Enter-NotifierMutex {
    $createdNew = $false
    $mutexInstance = New-Object System.Threading.Mutex($true, 'Local\ObsidianSystemTaskNotifier', [ref]$createdNew)
    return [pscustomobject]@{
        Mutex = $mutexInstance
        CreatedNew = $createdNew
    }
}

if ($CleanTestState) {
    $mutexInfo = Enter-NotifierMutex
    if (-not $mutexInfo.CreatedNew) {
        Write-DebugTrace -Message 'manual-clean waiting-for-running-notifier'
        $null = $mutexInfo.Mutex.WaitOne(15000)
    }
    try {
        $plan = Load-NotificationPlan
        $state = Load-State
        Ensure-StateShape -State $state
        $removedCount = Remove-StaleTaskState -State $state -Plan $plan -Now (Get-Date) -Force
        Save-State -State $state
        Write-RunLog -Message "manual clean test state removed=$removedCount"
        Write-DebugTrace -Message "manual-clean-test-state removed=$removedCount"
    }
    finally {
        if ($null -ne $mutexInfo.Mutex) {
            try { $mutexInfo.Mutex.ReleaseMutex() | Out-Null } catch {}
            $mutexInfo.Mutex.Dispose()
        }
    }
    exit 0
}

if ($TestToast) {
    $plan = [pscustomobject]@{ enableToast = $true; enableSound = $true; enableFallbackPopup = $true }
    $task = [pscustomobject]@{ time = (Get-Date).AddMinutes(1).ToString('HH:mm'); title = '系统提醒测试'; sourceFile = Get-TodayTodoPath; priority = 'test' }
    $displayRank = Get-TaskDisplayRank -Task $task -TaskState @{ lastNotifiedAt = '' } -Now (Get-Date)
    $popupMessage = Format-RemainingTasksSummary -CurrentTask $task -RemainingTasks @(
        [pscustomobject]@{ time = '19:10'; title = '驱动工作流（节后启动；重要不紧急）' },
        [pscustomobject]@{ time = '21:30'; title = '学习obsidian（重要紧急任务预留缓冲；提前准备与排除干扰）' },
        [pscustomobject]@{ time = '22:00'; title = '学习obsidian（今晚截止；重要紧急）' }
    ) -Now (Get-Date)
    Send-SystemTaskNotification -Task $task -Plan $plan -DisplayRank $displayRank -PopupMessage $popupMessage -RemainingTaskCount 3 -RemainingDisplayCount 3
    exit 0
}

$mutexInfo = Enter-NotifierMutex
$mutex = $mutexInfo.Mutex
$createdNew = [bool]$mutexInfo.CreatedNew
if (-not $createdNew) {
    Write-RunLog -Message 'System task notifier is already running; exiting duplicate instance.'
    Write-DebugTrace -Message 'mutex-duplicate-exit'
    exit 0
}

try {
    Write-RunLog -Message "System task notifier started. RunOnce=$RunOnce PollSeconds=$PollSeconds"
    do {
        Invoke-NotifierIteration
        if (-not $RunOnce) {
            Start-Sleep -Seconds $PollSeconds
        }
    } while (-not $RunOnce)
}
catch {
    Write-RunLog -Message "System task notifier failed: $($_.Exception.Message)"
    throw
}
finally {
    if ($null -ne $mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
