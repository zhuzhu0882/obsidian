#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TaskName = 'Obsidian-TodayTodo-OnLaunch',
    [string]$WatcherScript
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

if ([string]::IsNullOrWhiteSpace($WatcherScript)) {
    $WatcherScript = Join-Path $ScriptDirectory 'Start-TodayTodoOnObsidianLaunch.ps1'
}
if (-not (Test-Path -LiteralPath $WatcherScript -PathType Leaf)) {
    throw "Watcher script not found: $WatcherScript"
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
    $powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$watcherFullPath = (Resolve-Path -LiteralPath $WatcherScript).ProviderPath
$argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watcherFullPath`""
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
$description = 'Watch Obsidian launches and compensate today todo creation if midnight run was missed.'

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $watcherFullPath) -WindowStyle Hidden
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
