#Requires -Version 5.1
[CmdletBinding()]
param([string]$LauncherName = 'Obsidian-Claudian-AutoInstall.vbs')

$ErrorActionPreference = 'Stop'

$startupDir = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startupDir)) {
    $startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
}
$launcherPath = Join-Path $startupDir $LauncherName

if (Test-Path -LiteralPath $launcherPath -PathType Leaf) {
    Remove-Item -LiteralPath $launcherPath -Force
    Write-Output "Removed startup launcher: $launcherPath"
}
else {
    Write-Output "Startup launcher not found: $launcherPath"
}
