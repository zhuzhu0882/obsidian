#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$WatcherScript,
    [string]$LauncherName = 'Obsidian-Claudian-AutoInstall.vbs'
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
    $WatcherScript = Join-Path $ScriptDirectory 'Start-ClaudianAutoInstallLoop.ps1'
}

if (-not (Test-Path -LiteralPath $WatcherScript -PathType Leaf)) {
    throw "Watcher script not found: $WatcherScript"
}

$startupDir = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startupDir)) {
    $startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
}
if (-not (Test-Path -LiteralPath $startupDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $startupDir | Out-Null
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
    $powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$watcherFullPath = (Resolve-Path -LiteralPath $WatcherScript).ProviderPath
$command = '"{0}" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}"' -f $powerShellExe, $watcherFullPath
$vbsCommand = $command.Replace('"', '""')
$launcherPath = Join-Path $startupDir $LauncherName
$vbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "$vbsCommand", 0, False
"@

Set-Content -LiteralPath $launcherPath -Encoding ASCII -Value $vbs
Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $watcherFullPath) -WindowStyle Hidden

Get-Item -LiteralPath $launcherPath | Select-Object Name,FullName,Length,LastWriteTime

