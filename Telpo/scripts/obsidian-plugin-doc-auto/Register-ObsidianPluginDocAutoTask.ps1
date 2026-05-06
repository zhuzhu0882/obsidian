#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(1, 1440)][int]$IntervalMinutes = 10,
    [string]$TaskName = 'Obsidian-PluginDoc-AutoWatch',
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
    $WatcherScript = Join-Path $ScriptDirectory 'Start-ObsidianPluginDocAutoWatch.ps1'
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
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$periodicTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
$description = 'Watch Obsidian community plugin changes and auto-generate plugin documentation for this vault.'

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $periodicTrigger) -Settings $settings -Description $description -Force | Out-Null
Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $watcherFullPath) -WindowStyle Hidden
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
