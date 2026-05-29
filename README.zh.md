# claude-code-notify

[English](README.md)

为 [Claude Code](https://claude.ai/code) 提供 Windows 11 系统 Toast 通知。

## 功能

- **回答完成通知** — Claude 完成回复时弹出 Toast，停留 25 秒
- **需要确认通知** — Claude 等待操作批准时弹出紧急 Toast，不自动消失
- **点击跳回终端** — 点击通知自动聚焦到对应的 Windows Terminal 标签页
- **上下文信息** — 通知正文显示最后一条回复摘要，底部显示项目名和 Git 分支
- **多 Session 隔离** — 多个 Claude 会话同时运行互不干扰，各自 Toast 只跳回自己的标签页
- **多窗口支持** — 打开多个 Windows Terminal 窗口时也能准确定位到正确窗口

## 环境要求

- Windows 10 / 11
- 已安装并配置 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Windows Terminal（点击跳回标签页功能需要）
- Python 3，且在 PATH 中可用（命令为 `python`）
- Git Bash 或其他 bash shell（Claude Code 在 Windows 上的默认 shell）

## 安装

用 PowerShell 执行（无需管理员权限）：

```powershell
cd path\to\claude-code-notify
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

安装完成后**重启 Claude Code** 即可生效。

### 自定义安装目录

```powershell
.\install.ps1 -InstallDir "C:\Users\你的用户名\my-hooks"
```

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

会从 `settings.json` 中移除 hooks 并注销协议，脚本文件不会被删除。

## 工作原理

```
Claude Code 完成一轮回答
  └─ Stop hook 触发 → notify-stop.sh
       ├─ 从 transcript 读取最后一条回复 + cwd / 分支
       ├─ 保存当前 Windows Terminal 标签页（标题 + 序号 + 窗口 PID）
       └─ 弹出 Toast（25 秒，带 Claude 图标和项目信息）

Claude Code 需要确认
  └─ Notification hook 触发 → notify-notification.sh
       ├─ 读取 hook payload 中的 message 字段
       └─ 弹出紧急 Toast（不自动消失，需手动关闭）

用户点击 Toast
  └─ claude-code:// 协议 → focus-launcher.vbs（无 CMD 闪烁）
       └─ focus-window.ps1
            ├─ 根据保存的窗口 PID 定位正确的 WT 实例
            ├─ 将 Windows Terminal 窗口置于前台（保持最大化状态）
            └─ 切换到保存的标签页（先模糊匹配标题，失败则按序号兄底）
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `install.ps1` | 一键安装 / 卸载脚本 |
| `hooks/notify.ps1` | Toast 核心脚本，支持标题、正文、图标、attribution、场景、时长等参数 |
| `hooks/notify-stop.sh` | Stop hook 入口 |
| `hooks/notify-notification.sh` | Notification hook 入口 |
| `hooks/save-tab.ps1` | 弹通知前保存当前活跃标签页信息 |
| `hooks/focus-window.ps1` | 点击 Toast 后聚焦正确的标签页 |
| `hooks/focus-launcher.vbs` | 无闪烁启动 focus-window.ps1 的 VBScript 启动器 |
