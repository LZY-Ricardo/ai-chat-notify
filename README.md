# ai-chat-notify

为 **AI 对话类产品**（CLI / IDE 插件等）提供的 **Windows 通知**脚本：当一次对话/任务完成、报错或需要你回到界面时，用更友好的弹窗/气泡提醒你。

目前实现聚焦在 Windows（PowerShell + WPF / WinForms），后续可按 provider 适配更多产品（例如 Claude Code 等）。

## 特性

- `popup`：自绘 WPF 弹窗（置顶、圆角、可自动关闭、Esc 关闭）
- `balloon`：托盘气泡提示（`NotifyIcon.ShowBalloonTip`）
- 不阻塞调用方：外层脚本会启动一个隐藏的 PowerShell（`-STA`）子进程显示 UI
- 失败也不影响主流程：脚本总是 `exit 0`
- 事件输入：支持把事件 JSON 作为参数传入（包含对 Codex 事件的兼容解析）

## 快速开始（Windows）

从 PowerShell 调用（推荐 `powershell.exe`；安装了 PowerShell 7 也可用 `pwsh`）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details." `
  -Method "popup" -DurationSeconds 3 -NoSound
```

从任意工具/脚本（更通用）调用：

```bat
.\scripts\ai-chat-notify.cmd -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details."
```

## 事件 JSON 输入

你可以把事件 JSON **作为第 1 个位置参数**传入（方便做 hook）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  (Get-Content "./examples/codex-agent-turn-complete.json" -Raw)
```

### 推荐事件结构（通用）

`ai-chat-notify` 会优先读取这些字段（按需提供即可）：

```json
{
  "provider": "codex | claude-code | ...",
  "type": "turn_complete | error | needs_input | ...",
  "title": "标题（可选）",
  "subtitle": "副标题（可选）",
  "message": "正文（可选）",
  "method": "popup | balloon（可选）",
  "durationSeconds": 0,
  "noSound": true
}
```

### Codex 兼容

如果事件里包含 `type=agent-turn-complete` 且提供了 `input-messages`，会自动把副标题拼成：

`Turn complete: <首条输入的首行预览>`

## 环境变量

用于全局覆盖/注入配置（优先级：参数 > 环境变量 > 事件 JSON > 默认值）：

- `AI_CHAT_NOTIFY_TITLE`
- `AI_CHAT_NOTIFY_SUBTITLE`
- `AI_CHAT_NOTIFY_MESSAGE`
- `AI_CHAT_NOTIFY_METHOD`（`popup|balloon`）
- `AI_CHAT_NOTIFY_DURATION_SECONDS`
- `AI_CHAT_NOTIFY_NOSOUND`（`1/0`）
- `AI_CHAT_NOTIFY_LOG`（写入简单调试日志）

兼容读取 `CODEX_NOTIFY_*` 同名变量（便于从现有 Codex 配置迁移）。

## License

MIT
