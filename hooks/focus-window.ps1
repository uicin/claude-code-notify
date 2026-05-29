Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);
    public struct WINDOWPLACEMENT {
        public uint length, flags, showCmd;
        public int ptMinX, ptMinY, ptMaxX, ptMaxY, left, top, right, bottom;
    }
}
"@

$proc = Get-Process -Name "WindowsTerminal" -EA SilentlyContinue |
        Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $proc) { exit 1 }

$hwnd = $proc.MainWindowHandle

# Only restore if minimized — never resize a maximized/normal window
$wp = New-Object WinFocus+WINDOWPLACEMENT
$wp.length = [System.Runtime.InteropServices.Marshal]::SizeOf($wp)
[WinFocus]::GetWindowPlacement($hwnd, [ref]$wp) | Out-Null
if ($wp.showCmd -eq 2) {
    [WinFocus]::ShowWindow($hwnd, 9) | Out-Null
}
[WinFocus]::SetForegroundWindow($hwnd) | Out-Null

$info = Get-Content "$env:TEMP\claude-wt-tab.json" -EA SilentlyContinue | ConvertFrom-Json
if (-not $info) { exit 0 }

Start-Sleep -Milliseconds 200

$root  = [System.Windows.Automation.AutomationElement]::RootElement
$wtEl  = $root.FindFirst(
    [System.Windows.Automation.TreeScope]::Children,
    (New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)))
if (-not $wtEl) { exit 0 }

$tabCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::TabItem)
$tabs = $wtEl.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCond)
if ($tabs.Count -eq 0) { exit 0 }

function Select-Tab($tab) {
    try { $tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select(); return $true } catch {}
    try { $tab.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke();      return $true } catch {}
    return $false
}

# Strip leading spinner/status chars for fuzzy match
$normalize = { param($s) ($s -replace '^[\s\x{2800}-\x{28FF}✓✗]+\s*', '').Trim() }
$savedNorm  = & $normalize $info.title

# Pass 1: fuzzy title match
foreach ($tab in $tabs) {
    $n = & $normalize $tab.Current.Name
    if ($n -and $savedNorm -and ($n -eq $savedNorm -or $n -like "*$savedNorm*" -or $savedNorm -like "*$n*")) {
        Select-Tab $tab | Out-Null
        exit 0
    }
}

# Pass 2: index fallback
$idx = [int]$info.index
if ($idx -lt $tabs.Count) {
    Select-Tab $tabs[$idx] | Out-Null
}
