# claude-code-notify

[中文文档](README.zh.md)

Windows 11 Toast notifications for [Claude Code](https://claude.ai/code).

## Features

- **Completion notice** — toast pops up when Claude finishes a response (stays 25 s)
- **Action required** — urgent toast (stays until dismissed) when Claude needs your approval
- **Click to focus** — clicking the toast brings the correct Windows Terminal tab back to front
- **Context in notification** — shows the last assistant message, project name, and git branch

## Requirements

- Windows 10 / 11
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- Windows Terminal (for click-to-focus tab switching)
- Python 3 available as `python` in PATH
- Git Bash or any bash shell (Claude Code's default on Windows)

## Install

Open PowerShell (no admin required) and run:

```powershell
cd path\to\claude-code-notify
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then **restart Claude Code**. That's it.

### Custom install directory

```powershell
.\install.ps1 -InstallDir "C:\Users\you\my-hooks"
```

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

This removes the hooks from `settings.json` and unregisters the protocol. Hook script files are left in place.

## How it works

```
Claude Code finishes a turn
  └─ Stop hook fires → notify-stop.sh
       ├─ Reads transcript for last assistant message + cwd/branch
       ├─ Saves current Windows Terminal tab (title + index)
       └─ Shows Toast (25 s, Claude icon, attribution)

Claude Code needs attention
  └─ Notification hook fires → notify-notification.sh
       ├─ Reads message from hook payload
       └─ Shows urgent Toast (stays until dismissed)

User clicks Toast
  └─ claude-code:// protocol → focus-launcher.vbs (no CMD flash)
       └─ focus-window.ps1
            ├─ Brings Windows Terminal to front (preserves maximized state)
            └─ Switches to the saved tab (fuzzy title match + index fallback)
```

## Files

| File | Purpose |
|------|---------|
| `install.ps1` | One-click installer / uninstaller |
| `hooks/notify.ps1` | Core Toast script (title, message, icon, attribution, scenario, duration) |
| `hooks/notify-stop.sh` | Stop hook entry point |
| `hooks/notify-notification.sh` | Notification hook entry point |
| `hooks/save-tab.ps1` | Saves active Windows Terminal tab before showing toast |
| `hooks/focus-window.ps1` | Focuses correct tab on toast click |
| `hooks/focus-launcher.vbs` | Launches focus-window.ps1 without CMD flash |
