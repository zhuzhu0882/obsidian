# Obsidian Plugin Auto Install

This folder contains PowerShell automation for installing and enabling a bundled set of Obsidian plugins in every vault known to Obsidian.

## What It Installs

The bundled plugin list is stored in `plugins.json`; plugin files are stored under `plugins\<plugin-id>\`.

The current bundle contains the plugins from the referenced recommendation image, plus Claudian from the previous setup:

- Claudian
- Charts
- Mind Map
- Emoji Toolbar
- Annotator
- Media Extended
- Timelines (Revamped)
- Recent Files
- Calendar
- Dictionary
- Better Word Count
- CodeMirror Options
- Advanced Tables
- Remember cursor position
- Auto pair Chinese symbol
- Better footnote
- Tasks
- Kanban
- Day Planner
- Dataview
- QuickAdd
- Templater

## Files

- `Install-ClaudianToObsidianVaults.ps1`: legacy filename kept for the existing startup launcher. It now installs all bundled plugins.
- `Start-ClaudianAutoInstallLoop.ps1`: background watcher. It checks the Obsidian vault registry every 30 seconds and also runs a fallback sync every 5 minutes.
- `Install-ClaudianStartupLauncher.ps1`: installs a hidden Windows startup launcher and starts the watcher immediately.
- `Remove-ClaudianStartupLauncher.ps1`: removes the startup launcher.
- `plugins.json`: plugin metadata.
- `plugins\`: bundled plugin files used as the install source.

## Usage

Run once manually:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-ClaudianToObsidianVaults.ps1
```

Enable automatic sync at Windows login:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-ClaudianStartupLauncher.ps1
```

Remove automatic sync:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Remove-ClaudianStartupLauncher.ps1
```

## Notes

The script enables plugins by editing each vault's `.obsidian\community-plugins.json`. If a vault is already open when the script runs, Obsidian may need a reload or restart before plugin UIs appear.

`CodeMirror Options` and `Better footnote` are legacy plugins that are no longer in the current official community plugin index. They are bundled from their original GitHub releases because they appear in the requested image.

Logs are written under `logs\` in this folder.
