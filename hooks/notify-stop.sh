#!/bin/bash
INPUT=$(cat)

# Skip if triggered by a previous stop hook (prevent duplicate/cascade notifications)
echo "$INPUT" | python -c "
import sys, json
d = json.load(sys.stdin)
sys.exit(1 if d.get('stop_hook_active') else 0)
" || exit 0

# Resolve hooks directory as Windows path (works in Git Bash / MSYS2)
_dir="$(dirname "$0")"
HOOKS_WIN=$(cygpath -w "$_dir" 2>/dev/null || echo "$_dir" | sed 's|/\([A-Za-z]\)/|\1:/|;s|/|\\|g')

# Extract last assistant message + project/branch attribution from transcript
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
                if not cwd and obj.get('cwd'):
                    cwd = obj['cwd']
                if not git_branch and obj.get('gitBranch') is not None:
                    git_branch = obj['gitBranch']
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
        last_text = 'Done'
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
        f.write('Done')
    open(tmp + '/claude-notify-attr.txt', 'w').close()
"

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
  -File "$HOOKS_WIN\\save-tab.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
  -File "$HOOKS_WIN\\notify.ps1" \
  -Title "Claude Code" \
  -MessageFile "$TEMP\\claude-notify-msg.txt" \
  -AttributionFile "$TEMP\\claude-notify-attr.txt" \
  -Duration "long"
