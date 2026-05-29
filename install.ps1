#Requires -Version 5.1
<#
.SYNOPSIS
    Installs claude-code-notify: Windows Toast notifications for Claude Code.
.DESCRIPTION
    - Copies hook scripts to ~/.claude/hooks/
    - Downloads the Claude icon
    - Registers the Claude.Code AUMID and claude-code:// protocol
    - Updates ~/.claude/settings.json with Stop and Notification hooks
.PARAMETER InstallDir
    Target directory for hook scripts. Defaults to ~/.claude/hooks/
.PARAMETER Uninstall
    Remove hooks from settings.json and unregister the protocol.
#>
param(
    [string]$InstallDir = "",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$claudeDir   = "$env:USERPROFILE\.claude"
$settingsFile = "$claudeDir\settings.json"
if (-not $InstallDir) { $InstallDir = "$claudeDir\hooks" }
$InstallDir  = $InstallDir.TrimEnd('\\')

# ── Uninstall ──────────────────────────────────────────────────────────────────────────────
if ($Uninstall) {
    Write-Host "Removing claude-code-notify..."
    # Remove protocol
    Remove-Item "HKCU:\SOFTWARE\Classes\claude-code" -Recurse -Force -EA SilentlyContinue
    # Remove AUMID
    Remove-Item "HKCU:\SOFTWARE\Classes\AppUserModelId\Claude.Code" -Recurse -Force -EA SilentlyContinue
    # Remove hooks from settings.json
    if (Test-Path $settingsFile) {
        $s = Get-Content $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $s.PSObject.Properties.Remove("hooks")
        $s | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    }
    Write-Host "Done. Hook scripts in '$InstallDir' were left in place."
    exit 0
}

# ── Install ─────────────────────────────────────────────────────────────────────────────────
Write-Host "Installing claude-code-notify to: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Copy hook scripts
$srcDir = Join-Path $PSScriptRoot "hooks"
Copy-Item "$srcDir\*" $InstallDir -Force
Write-Host "  [ok] Hook scripts copied"

# Download Claude icon
$iconDest = "$InstallDir\claude-icon.png"
try {
    Invoke-WebRequest -Uri "https://claude.ai/apple-touch-icon.png" `
        -OutFile $iconDest -UseBasicParsing -TimeoutSec 10
    Write-Host "  [ok] Icon downloaded"
} catch {
    Write-Host "  [warn] Could not download icon (notifications will work without it)"
}

# Register AUMID
$regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\Claude.Code"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code"
Write-Host "  [ok] AUMID registered"

# Register claude-code:// protocol (no CMD flash via wscript launcher)
$launcherPath = "$InstallDir\focus-launcher.vbs"
$handler      = "wscript.exe //B //NoLogo `"$launcherPath`" `"%1`""
$regBase      = "HKCU:\SOFTWARE\Classes\claude-code"
New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name "(Default)"    -Value "URL:Claude Code Protocol"
Set-ItemProperty -Path $regBase -Name "URL Protocol" -Value ""
New-Item -Path "$regBase\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$regBase\shell\open\command" -Name "(Default)" -Value $handler
Write-Host "  [ok] Protocol claude-code:// registered"

# Build settings.json hook commands (forward slashes for bash compatibility)
$hooksForward = $InstallDir -replace '\\', '/'
$stopCmd      = "bash '$hooksForward/notify-stop.sh'"
$notifCmd     = "bash '$hooksForward/notify-notification.sh'"

# Merge hooks into settings.json
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

$hooksObj = [PSCustomObject]@{
    Stop         = @([PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = "command"; command = $stopCmd }) })
    Notification = @([PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = "command"; command = $notifCmd }) })
}
if ($settings.PSObject.Properties["hooks"]) {
    $settings.hooks = $hooksObj
} else {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue $hooksObj
}
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
Write-Host "  [ok] settings.json updated"

Write-Host ""
Write-Host "Installation complete. Restart Claude Code to apply hooks."
