#Requires -Version 5.1
[CmdletBinding()]
param([string]$TaskName = 'Obsidian-Claudian-AutoInstall')

$ErrorActionPreference = 'Stop'

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "Removed scheduled task: $TaskName"
}
else {
    Write-Output "Scheduled task not found: $TaskName"
}
