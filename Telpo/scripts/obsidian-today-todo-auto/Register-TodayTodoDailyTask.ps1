#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TaskName = 'Obsidian-TodayTodo-Daily',
    [string]$RunnerScript
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

if ([string]::IsNullOrWhiteSpace($RunnerScript)) {
    $RunnerScript = Join-Path $ScriptDirectory 'Start-TodayTodoDailyRun.ps1'
}
if (-not (Test-Path -LiteralPath $RunnerScript -PathType Leaf)) {
    throw "Runner script not found: $RunnerScript"
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
    $powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$runnerFullPath = (Resolve-Path -LiteralPath $RunnerScript).ProviderPath
$argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runnerFullPath`" -Mode scheduled"
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $argument
$trigger = New-ScheduledTaskTrigger -Daily -At 12:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
$description = 'Create today todo note at midnight and migrate unfinished tasks from yesterday.'

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
