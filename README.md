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

### 可视化配置器（Windows）

用于“傻瓜式”配置弹窗样式与默认文案，并可一键复制用于集成的命令片段（stdin / `-EventFile` / 位置参数）。

#### 免安装运行（推荐先体验）

```bat
.\ai-chat-notify-config.cmd
```

#### 安装后运行（如果安装时使用了 `-AddToPath`）

```powershell
ai-chat-notify-config
```

配置器支持：
- 编辑并保存 `config.json`（默认路径见下文）
- 一键测试 `popup` / `balloon`
- 复制“集成片段”到剪贴板（用于粘贴到 Codex/Claude Code 等产品的 hook 配置里）
- 一键写入 Codex `config.toml` 的 `notify`（会创建备份；重启 Codex 生效）

### 免安装（最简单，适合做 hook）
在仓库根目录直接运行：

```bat
.\ai-chat-notify.cmd -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details."
```

也可以显式调用脚本目录里的包装器：

```bat
.\scripts\ai-chat-notify.cmd -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details."
```

### 安装（可选：让 `ai-chat-notify` 全局可用）
在仓库根目录运行（会把脚本复制到用户目录；`-AddToPath` 会修改你的用户级 PATH）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./install.ps1" -AddToPath
```

重启终端后即可直接调用：

```powershell
ai-chat-notify -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details."
```

卸载（可选：`-RemoveFromPath` 会修改你的用户级 PATH）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./uninstall.ps1" -RemoveFromPath
```

安装后也支持直接用 `stdin` 传事件 JSON：

```powershell
Get-Content "./examples/codex-agent-turn-complete.json" -Raw | ai-chat-notify -Method "popup" -DurationSeconds 2 -NoSound
```

从 PowerShell 直接调用入口脚本（不依赖 `.cmd`）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details." `
  -Method "popup" -DurationSeconds 3 -NoSound
```

## 配置文件（config.json）

默认路径（自动创建目录）：
- `%LOCALAPPDATA%\ai-chat-notify\config.json`
- fallback：`%USERPROFILE%\.ai-chat-notify\config.json`

你也可以显式指定配置路径：
- 参数：`-ConfigPath "C:\path\to\config.json"`
- 环境变量：`AI_CHAT_NOTIFY_CONFIG_PATH`（兼容 `CODEX_NOTIFY_CONFIG_PATH`）

配置结构示例：`./examples/config.sample.json`（单配置；暂不支持 profiles）

优先级（从高到低）：
- 文案（`Title/Subtitle/Message`）：环境变量 > 参数 > 事件 JSON > `config.json` > 内置默认
- 其他（`method/durationSeconds/noSound`）：参数 > 环境变量 > 事件 JSON > `config.json` > 内置默认

## 事件 JSON 输入

三种方式任选其一（更推荐 `stdin` 或 `-EventFile`，避免转义/引号问题）：

### 1) 位置参数（兼容 Codex hook）
你可以把事件 JSON **作为第 1 个位置参数**传入：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  (Get-Content "./examples/codex-agent-turn-complete.json" -Raw)
```

### 2) stdin（推荐：最好集成、最少转义）

```powershell
Get-Content "./examples/codex-agent-turn-complete.json" -Raw | .\ai-chat-notify.cmd -Method "popup" -DurationSeconds 2 -NoSound
```

### 3) `-EventFile`

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  -EventFile "./examples/codex-agent-turn-complete.json" -Method "popup" -DurationSeconds 2 -NoSound
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

用于全局覆盖/注入配置：

- `AI_CHAT_NOTIFY_TITLE`
- `AI_CHAT_NOTIFY_SUBTITLE`
- `AI_CHAT_NOTIFY_MESSAGE`
- `AI_CHAT_NOTIFY_METHOD`（`popup|balloon`）
- `AI_CHAT_NOTIFY_DURATION_SECONDS`
- `AI_CHAT_NOTIFY_NOSOUND`（`1/0`）
- `AI_CHAT_NOTIFY_LOG`（写入简单调试日志）
- `AI_CHAT_NOTIFY_CONFIG_PATH`（配置文件路径）

兼容读取 `CODEX_NOTIFY_*` 同名变量（便于从现有 Codex 配置迁移）。

## License

MIT
