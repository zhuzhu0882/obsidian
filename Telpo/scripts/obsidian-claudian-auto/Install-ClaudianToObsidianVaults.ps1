#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ObsidianConfigPath,
    [string]$PluginSourceRoot,
    [string]$PluginManifestPath,
    [string]$LogPath
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

if ([string]::IsNullOrWhiteSpace($ObsidianConfigPath)) {
    $ObsidianConfigPath = Join-Path $env:APPDATA 'obsidian\obsidian.json'
}
if ([string]::IsNullOrWhiteSpace($PluginSourceRoot)) {
    $PluginSourceRoot = Join-Path $ScriptDirectory 'plugins'
}
if ([string]::IsNullOrWhiteSpace($PluginManifestPath)) {
    $PluginManifestPath = Join-Path $ScriptDirectory 'plugins.json'
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $ScriptDirectory 'logs\obsidian-plugin-auto-install.log'
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Write-InstallLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logDir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        Ensure-Directory -Path $logDir
    }

    $line = "[$stamp] $Message"
    Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value $line
    Write-Output $line
}

function Get-JsonFileValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()]$DefaultValue
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $DefaultValue
    }

    $raw = Get-Content -Raw -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $DefaultValue
    }

    try {
        return ($raw | ConvertFrom-Json)
    }
    catch {
        Write-InstallLog -Message "Invalid JSON, using default: $Path"
        return $DefaultValue
    }
}

function ConvertTo-JsonArrayText {
    param([Parameter(Mandatory = $true)][string[]]$Items)

    if ($Items.Count -eq 0) {
        return "[]"
    }

    $encodedItems = foreach ($item in $Items) {
        ConvertTo-Json -InputObject ([string]$item) -Compress
    }

    return "[`r`n  $($encodedItems -join ",`r`n  ")`r`n]"
}

function Get-EnabledCommunityPlugins {
    param([Parameter(Mandatory = $true)][string]$Path)

    $value = Get-JsonFileValue -Path $Path -DefaultValue @()
    if ($null -eq $value) {
        return @()
    }

    if ($value -is [string]) {
        return @([string]$value)
    }

    return @($value | ForEach-Object { [string]$_ })
}

function Set-EnabledCommunityPlugins {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Plugins
    )

    $json = ConvertTo-JsonArrayText -Items $Plugins
    Set-Content -LiteralPath $Path -Encoding UTF8 -Value $json
}

function Test-SamePath {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    try {
        $leftResolved = (Resolve-Path -LiteralPath $Left -ErrorAction Stop).ProviderPath.TrimEnd('\')
        $rightResolved = (Resolve-Path -LiteralPath $Right -ErrorAction Stop).ProviderPath.TrimEnd('\')
        return ([string]::Equals($leftResolved, $rightResolved, [System.StringComparison]::OrdinalIgnoreCase))
    }
    catch {
        return $false
    }
}

function Get-PluginDefinitions {
    if (Test-Path -LiteralPath $PluginManifestPath -PathType Leaf) {
        $definitions = Get-JsonFileValue -Path $PluginManifestPath -DefaultValue @()
        return @($definitions | ForEach-Object {
            [pscustomobject]@{
                id = [string]$_.id
                name = [string]$_.name
                repo = [string]$_.repo
                tag = [string]$_.tag
                note = [string]$_.note
            }
        })
    }

    if (-not (Test-Path -LiteralPath $PluginSourceRoot -PathType Container)) {
        throw "Plugin source root not found: $PluginSourceRoot"
    }

    return @(Get-ChildItem -LiteralPath $PluginSourceRoot -Directory | ForEach-Object {
        [pscustomobject]@{ id = $_.Name; name = $_.Name; repo = ''; tag = ''; note = '' }
    })
}

function Assert-PluginSource {
    param(
        [Parameter(Mandatory = $true)][string]$PluginId,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Plugin source directory not found for ${PluginId}: $Path"
    }

    foreach ($requiredFile in @('main.js', 'manifest.json')) {
        $requiredPath = Join-Path $Path $requiredFile
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Plugin ${PluginId} source is missing ${requiredFile}: $Path"
        }
    }

    $manifestPath = Join-Path $Path 'manifest.json'
    $manifest = Get-JsonFileValue -Path $manifestPath -DefaultValue $null
    if ($null -ne $manifest) {
        $idProperty = $manifest.PSObject.Properties['id']
        if ($null -ne $idProperty -and $idProperty.Value -ne $PluginId) {
            Write-InstallLog -Message "Warning: source folder '$PluginId' manifest id is '$($idProperty.Value)'. Obsidian will enable manifest id."
            return [string]$idProperty.Value
        }
    }

    return $PluginId
}

function Copy-PluginSource {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$TargetDir
    )

    Ensure-Directory -Path $TargetDir
    if (Test-SamePath -Left $SourceDir -Right $TargetDir) {
        return
    }

    Get-ChildItem -Force -LiteralPath $SourceDir | Where-Object { $_.Name -ne 'data.json' } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $TargetDir -Recurse -Force
    }
}

function Install-PluginsForVault {
    param(
        [Parameter(Mandatory = $true)][string]$VaultPath,
        [Parameter(Mandatory = $true)][object[]]$Plugins
    )

    $obsidianDir = Join-Path $VaultPath '.obsidian'
    $pluginsDir = Join-Path $obsidianDir 'plugins'
    $communityPluginsPath = Join-Path $obsidianDir 'community-plugins.json'

    Ensure-Directory -Path $obsidianDir
    Ensure-Directory -Path $pluginsDir

    $enabledPlugins = Get-EnabledCommunityPlugins -Path $communityPluginsPath
    $changed = $false
    $installedCount = 0

    foreach ($plugin in $Plugins) {
        if ([string]::IsNullOrWhiteSpace($plugin.id)) {
            Write-InstallLog -Message "Skipped plugin definition without id."
            continue
        }

        $sourceDir = Join-Path $PluginSourceRoot $plugin.id
        $manifestId = Assert-PluginSource -PluginId $plugin.id -Path $sourceDir
        $targetPluginDir = Join-Path $pluginsDir $manifestId

        Copy-PluginSource -SourceDir $sourceDir -TargetDir $targetPluginDir
        $installedCount++

        if ($enabledPlugins -notcontains $manifestId) {
            $enabledPlugins = @($enabledPlugins) + $manifestId
            $changed = $true
        }
    }

    if ($changed) {
        Set-EnabledCommunityPlugins -Path $communityPluginsPath -Plugins $enabledPlugins
        Write-InstallLog -Message "Installed/enabled plugins for vault: $VaultPath; installed=$installedCount; enabledTotal=$($enabledPlugins.Count)"
    }
    else {
        Write-InstallLog -Message "Plugins already installed/enabled for vault: $VaultPath; installed=$installedCount; enabledTotal=$($enabledPlugins.Count)"
    }
}

$pluginDefinitions = Get-PluginDefinitions
if ($pluginDefinitions.Count -eq 0) {
    Write-InstallLog -Message "No plugin definitions found."
    exit 1
}

if (-not (Test-Path -LiteralPath $ObsidianConfigPath -PathType Leaf)) {
    Write-InstallLog -Message "Obsidian vault registry not found: $ObsidianConfigPath"
    exit 0
}

$config = Get-JsonFileValue -Path $ObsidianConfigPath -DefaultValue $null
if ($null -eq $config) {
    Write-InstallLog -Message "Unable to read Obsidian vault registry: $ObsidianConfigPath"
    exit 1
}

$vaultsProperty = $config.PSObject.Properties['vaults']
if ($null -eq $vaultsProperty -or $null -eq $vaultsProperty.Value) {
    Write-InstallLog -Message "No vaults found in Obsidian registry: $ObsidianConfigPath"
    exit 0
}

$processed = 0
$skipped = 0
foreach ($vaultProperty in $vaultsProperty.Value.PSObject.Properties) {
    $pathProperty = $vaultProperty.Value.PSObject.Properties['path']
    if ($null -eq $pathProperty -or [string]::IsNullOrWhiteSpace([string]$pathProperty.Value)) {
        $skipped++
        Write-InstallLog -Message "Skipped vault entry without path: $($vaultProperty.Name)"
        continue
    }

    $vaultPath = [string]$pathProperty.Value
    if (-not (Test-Path -LiteralPath $vaultPath -PathType Container)) {
        $skipped++
        Write-InstallLog -Message "Skipped missing vault path: $vaultPath"
        continue
    }

    Install-PluginsForVault -VaultPath $vaultPath -Plugins $pluginDefinitions
    $processed++
}

Write-InstallLog -Message "Finished. Plugins=$($pluginDefinitions.Count); processed vaults=$processed; skipped entries=$skipped."
