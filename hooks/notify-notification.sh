#!/bin/bash
INPUT=$(cat)

echo "$INPUT" | python -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    msg = d.get('message', 'Needs your attention')
except:
    msg = 'Needs your attention'
tmp = os.environ.get('TEMP', '/tmp')
with open(tmp + '/claude-notify-msg.txt', 'w', encoding='utf-8') as f:
    f.write(msg)
"

_dir="$(dirname "$0")"
HOOKS_WIN=$(cygpath -w "$_dir" 2>/dev/null || echo "$_dir" | sed 's|/\([A-Za-z]\)/|\1:/|;s|/|\\|g')

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
  -File "$HOOKS_WIN\\save-tab.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
  -File "$HOOKS_WIN\\notify.ps1" \
  -Title "Claude Code — Action Required" \
  -MessageFile "$TEMP\\claude-notify-msg.txt" \
  -Scenario "urgent"
