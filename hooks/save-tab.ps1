param([string]$Session = "")

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
public class ProcHelper {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Auto)]
    public struct PROCESSENTRY32 {
        public uint dwSize, cntUsage, th32ProcessID; public IntPtr th32DefaultHeapID;
        public uint th32ModuleID, cntThreads, th32ParentProcessID; public int pcPriClassBase;
        public uint dwFlags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string szExeFile;
    }
    [DllImport("kernel32.dll")] static extern IntPtr CreateToolhelp32Snapshot(uint f, uint p);
    [DllImport("kernel32.dll")] static extern bool Process32First(IntPtr h, ref PROCESSENTRY32 e);
    [DllImport("kernel32.dll")] static extern bool Process32Next(IntPtr h, ref PROCESSENTRY32 e);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    public static Dictionary<int,int> GetParentMap() {
        var map = new Dictionary<int,int>();
        var h = CreateToolhelp32Snapshot(2, 0);
        var e = new PROCESSENTRY32(); e.dwSize = (uint)Marshal.SizeOf(e);
        if (Process32First(h, ref e)) do { map[(int)e.th32ProcessID] = (int)e.th32ParentProcessID; } while (Process32Next(h, ref e));
        CloseHandle(h); return map;
    }
}
"@

# --- Identify which WT owns this session via process tree ---
$map = [ProcHelper]::GetParentMap()
$wtPids = @{}
Get-Process -Name "WindowsTerminal" -EA SilentlyContinue | ForEach-Object { $wtPids[[int]$_.Id] = $_ }
if ($wtPids.Count -eq 0) { exit 0 }

# Walk up from $PID to find the tab shell (direct child of any WT)
$cur = [int]$PID; $tabShellPid = 0; $wtProc = $null
for ($i = 0; $i -lt 10; $i++) {
    $parent = 0; if ($map.ContainsKey($cur)) { $parent = $map[$cur] }
    if ($wtPids.ContainsKey($parent)) { $tabShellPid = $cur; $wtProc = $wtPids[$parent]; break }
    if ($parent -le 1) { break }
    $cur = $parent
}

# Fallback to newest WT if process tree didn't resolve
if (-not $wtProc) { $wtProc = $wtPids.Values | Sort-Object StartTime -Descending | Select-Object -First 1 }

# Get WT direct children (excluding OpenConsole = console server, not the shell)
# sorted by start time → position in this list = UIAutomation tab index
$wtShells = Get-Process | Where-Object {
    $map.ContainsKey([int]$_.Id) -and
    $map[[int]$_.Id] -eq [int]$wtProc.Id -and
    $_.Name -ne "OpenConsole"
} | Sort-Object StartTime

$tabIdx = -1; $i = 0
foreach ($c in $wtShells) {
    if ($c.Id -eq $tabShellPid) { $tabIdx = $i; break }
    $i++
}

# --- Get tab title from UIAutomation ---
$root = [System.Windows.Automation.AutomationElement]::RootElement
$wtEl = $root.FindFirst(
    [System.Windows.Automation.TreeScope]::Children,
    (New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $wtProc.Id)))

$savedTitle = $wtProc.MainWindowTitle  # fallback
if ($wtEl -and $tabIdx -ge 0) {
    $tabCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::TabItem)
    $tabs = $wtEl.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCond)
    if ($tabIdx -lt $tabs.Count) {
        $savedTitle = $tabs[$tabIdx].Current.Name
    }
}

# Fallback to selected tab if process tree didn't resolve
if ($tabIdx -lt 0) {
    $tabIdx = 0
    if ($wtEl) {
        $tabCond = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::TabItem)
        $tabs = $wtEl.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCond)
        $j = 0
        foreach ($tab in $tabs) {
            try {
                if ($tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Current.IsSelected) {
                    $tabIdx = $j; $savedTitle = $tab.Current.Name; break
                }
            } catch {}
            $j++
        }
    }
}

$tabFile = if ($Session) { "$env:TEMP\claude-wt-tab-$Session.json" } else { "$env:TEMP\claude-wt-tab.json" }
@{ title = $savedTitle; index = $tabIdx; wtPid = $wtProc.Id } | ConvertTo-Json | Out-File $tabFile -Encoding UTF8
