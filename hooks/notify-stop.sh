#!/bin/bash
INPUT=$(cat)

# Skip if triggered by a previous stop hook (prevent duplicate/cascade notifications)
echo "$INPUT" | python -c "
import sys, json
d = json.load(sys.stdin)
sys.exit(1 if d.get('stop_hook_active') else 0)
" || exit 0

# Extract message + attribution (project name, git branch) from transcript
echo "$INPUT" | python -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
    path = data.get('transcript_path', '')
    last_text = ''
    cwd = ''
    git_branch = ''

    if path:
        with open(path, encoding='utf-8') as f:
            lines = [l.strip() for l in f if l.strip()]
        for line in reversed(lines):
            try:
                obj = json.loads(line)
                # pick up cwd/gitBranch from any recent entry
                if not cwd and obj.get('cwd'):
                    cwd = obj['cwd']
                if not git_branch and obj.get('gitBranch') is not None:
                    git_branch = obj['gitBranch']
                # pick up last assistant text
                if not last_text and obj.get('type') == 'assistant':
                    content = obj.get('message', {}).get('content', [])
                    if isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get('type') == 'text':
                                last_text = block.get('text', '').strip()
                                break
                if last_text and cwd and git_branch is not None:
                    break
            except:
                pass

    if not last_text:
        last_text = '回答已完成，可以回来查看了'
    else:
        text = last_text.replace('\n', ' ')
        last_text = (text[:80] + '...') if len(text) > 80 else text

    project = os.path.basename(cwd.rstrip('/\\\\')) if cwd else ''
    attribution = project
    if git_branch:
        attribution = (project + '  |  ' + git_branch) if project else git_branch

    tmp = os.environ.get('TEMP', '/tmp')
    with open(tmp + '/claude-notify-msg.txt', 'w', encoding='utf-8') as f:
        f.write(last_text)
    with open(tmp + '/claude-notify-attr.txt', 'w', encoding='utf-8') as f:
        f.write(attribution)
except:
    tmp = os.environ.get('TEMP', '/tmp')
    with open(tmp + '/claude-notify-msg.txt', 'w', encoding='utf-8') as f:
        f.write('回答已完成，可以回来查看了')
    open(tmp + '/claude-notify-attr.txt', 'w').close()
"

_dir="$(dirname "$0")"
HOOKS_WIN=$(cygpath -w "$_dir" 2>/dev/null || echo "$_dir" | sed 's|/\([A-Za-z]\)/|\1:/|;s|/|\\|g')

if [ -n "$WT_SESSION" ]; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
    -File "$HOOKS_WIN\\save-tab.ps1" -Session "$WT_SESSION"
  LAUNCH_URL="claude-code://focus?s=$WT_SESSION"
else
  LAUNCH_URL=""
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
  -File "$HOOKS_WIN\\notify.ps1" \
  -Title "Claude Code 完成" \
  -MessageFile "$TEMP\\claude-notify-msg.txt" \
  -AttributionFile "$TEMP\\claude-notify-attr.txt" \
  -Duration "long" \
  -LaunchUrl "$LAUNCH_URL"
