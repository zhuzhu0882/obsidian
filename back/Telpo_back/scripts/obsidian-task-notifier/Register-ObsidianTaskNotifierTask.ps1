#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(1, 60)][int]$IntervalMinutes = 1,
    [string]$TaskName = 'Obsidian-SystemTaskNotifier',
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
    $RunnerScript = Join-Path $ScriptDirectory 'Start-ObsidianTaskNotifier.ps1'
}
if (-not (Test-Path -LiteralPath $RunnerScript -PathType Leaf)) {
    throw "Runner script not found: $RunnerScript"
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
    $powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$runnerFullPath = (Resolve-Path -LiteralPath $RunnerScript).ProviderPath
$argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runnerFullPath`" -RunOnce"
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $argument
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$periodicTrigger = New-ScheduledTaskTrigger -Daily -At ((Get-Date).AddMinutes(1).ToString('HH:mm'))
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
$description = 'Check today Day Planner tasks and send Windows system notifications with fallback alerts.'

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $periodicTrigger) -Settings $settings -Description $description -Force | Out-Null
Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $runnerFullPath, '-RunOnce') -WindowStyle Hidden
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
