#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(1, 1440)][int]$IntervalMinutes = 5,
    [string]$TaskName = 'Obsidian-Claudian-AutoInstall',
    [string]$InstallerScript
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

if (-not (Test-Path -LiteralPath $InstallerScript -PathType Leaf)) {
    throw "Installer script not found: $InstallerScript"
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
    $powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$installerFullPath = (Resolve-Path -LiteralPath $InstallerScript).ProviderPath
$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$installerFullPath`""
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $argument
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$periodicTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
$description = "Install and enable the Claudian Obsidian plugin for every vault recorded in Obsidian's vault registry."

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $periodicTrigger) -Settings $settings -Description $description -Force | Out-Null

& $installerFullPath
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
