Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$proc = Get-Process -Name "WindowsTerminal" -EA SilentlyContinue |
        Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $proc) { exit 0 }

$title = $proc.MainWindowTitle

$root = [System.Windows.Automation.AutomationElement]::RootElement
$wtEl = $root.FindFirst(
    [System.Windows.Automation.TreeScope]::Children,
    (New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)))

$savedIdx = 0
if ($wtEl) {
    $tabCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::TabItem)
    $tabs = $wtEl.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCond)
    $i = 0
    foreach ($tab in $tabs) {
        try {
            $sel = $tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            if ($sel.Current.IsSelected) { $savedIdx = $i; break }
        } catch {}
        $i++
    }
}

@{ title = $title; index = $savedIdx } | ConvertTo-Json |
    Out-File "$env:TEMP\claude-wt-tab.json" -Encoding UTF8
