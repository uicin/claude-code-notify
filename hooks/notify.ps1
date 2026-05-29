param(
    [string]$Title = "Claude Code",
    [string]$Message = "Notification",
    [string]$MessageFile = "",
    [string]$Attribution = "",
    [string]$AttributionFile = "",
    [string]$Scenario = "",
    [string]$Duration = "",
    [string]$Action1 = "",
    [string]$Action2 = "",
    [string]$Action1Args = "",
    [string]$Action2Args = ""
)

if ($MessageFile -and (Test-Path $MessageFile)) {
    $Message = [System.IO.File]::ReadAllText($MessageFile, [System.Text.Encoding]::UTF8).Trim()
}
if ($AttributionFile -and (Test-Path $AttributionFile)) {
    $Attribution = [System.IO.File]::ReadAllText($AttributionFile, [System.Text.Encoding]::UTF8).Trim()
}
if (-not $Message) { $Message = "Notification" }

try {
    $AppId = "Claude.Code"
    $regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$AppId"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code"
    }

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $escapedMsg  = [System.Security.SecurityElement]::Escape($Message)
    $escapedAttr = [System.Security.SecurityElement]::Escape($Attribution)

    $iconPath = Join-Path $PSScriptRoot "claude-icon.png"
    $iconXml  = if (Test-Path $iconPath) { "<image placement='appLogoOverride' src='$iconPath' hint-crop='circle'/>" } else { "" }
    $attrXml  = if ($Attribution) { "<text placement='attribution'>$escapedAttr</text>" } else { "" }
    $scenAttr = if ($Scenario) { "scenario='$Scenario'" } else { "" }
    $durAttr  = if ($Duration) { "duration='$Duration'" } else { "" }

    if ($Action1 -and $Action2) {
        $toastXml = @"
<toast launch='claude-code://focus' activationType='protocol' $scenAttr $durAttr>
  <visual>
    <binding template='ToastGeneric'>
      $iconXml
      <text>$Title</text>
      <text>$escapedMsg</text>
      $attrXml
    </binding>
  </visual>
  <actions>
    <action content='$Action1' arguments='$Action1Args' activationType='protocol'/>
    <action content='$Action2' arguments='$Action2Args' activationType='protocol'/>
  </actions>
</toast>
"@
    } else {
        $toastXml = @"
<toast launch='claude-code://focus' activationType='protocol' $scenAttr $durAttr>
  <visual>
    <binding template='ToastGeneric'>
      $iconXml
      <text>$Title</text>
      <text>$escapedMsg</text>
      $attrXml
    </binding>
  </visual>
</toast>
"@
    }

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
} catch {
    Write-Host "Toast error: $_"
}
