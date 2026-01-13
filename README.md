# ai-chat-notify

为 **AI 对话类产品**（CLI / IDE 插件等）提供的 **Windows 通知**脚本：目前用于在一次对话/任务**正常结束**时，用更友好的弹窗/气泡提醒你。

目前实现聚焦在 Windows（PowerShell + WPF / WinForms），后续会逐步增强事件类型适配，并按 provider 适配更多产品（例如 Claude Code 等）。

## 特性

- `popup`：自绘 WPF 弹窗（置顶、圆角、可自动关闭、Esc 关闭）
- `balloon`：托盘气泡提示（`NotifyIcon.ShowBalloonTip`）
- 不阻塞调用方：外层脚本会启动一个隐藏的 PowerShell（`-STA`）子进程显示 UI
- 失败也不影响主流程：脚本总是 `exit 0`
- 事件输入：支持把事件 JSON 作为参数传入（包含对 Codex 事件的兼容解析）

## 快速开始（Windows）   

### 可视化配置器（Windows）

用于“傻瓜式”配置弹窗样式与默认文案，并可一键复制用于集成的命令片段（argv 末尾追加 JSON / `-EventFile` / `-EventJson`）。

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
- 复制“集成片段”到剪贴板（已改为更稳的 `powershell.exe -File ... -EventJson` 形式）
- Codex 集成：打开/检查/复制 `notify`，保存并写入 `config.toml`（自动备份/可恢复；重启 Codex 生效）
- 调试日志：可视化开关 `-LogPath`，并支持一键打开日志文件

#### 新手流程（接入 Codex，推荐）

1) 运行配置器：`.\ai-chat-notify-config.cmd`  
2) 在“基础/样式”页配置文案与样式，点击“测试 Popup/balloon”预览  
3) 右下角点击“保存配置”  
4) 点击“去配置 Codex” → 在“安装/集成”页点击“保存并写入 notify”  
5) 重启 `codex`（CLI/IDE 插件都需要重启才能加载新配置）  
6) 回到配置器点击“检查 notify”确认是否匹配当前配置器生成的 `notify`

> 提示：如果写坏了 `config.toml` 导致 Codex 无法启动，可在配置器里点“恢复最近备份”。

#### Codex 集成（手动写入 config.toml）

如果你不想用配置器自动写入，也可以手动编辑 Codex 配置文件：`%USERPROFILE%\.codex\config.toml`。

**关键点：**
- `notify` 是“argv 数组”，不要把整条命令拼成一个字符串塞进数组
- 推荐用正斜杠路径（`C:/...`），避免反斜杠转义
- 确保 `-EventJson` 在 argv 最后：Codex 会在最后追加事件 JSON 作为它的值

示例（推荐：直接调用 `ai-chat-notify.ps1`）：

```toml
notify = [
  "powershell.exe",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  "C:/Users/<you>/AppData/Local/ai-chat-notify/bin/ai-chat-notify.ps1",
  "-ConfigPath",
  "C:/Users/<you>/AppData/Local/ai-chat-notify/config.json",
  "-EventJson",
]
```

开启日志（可选）：

```toml
notify = [
  "powershell.exe",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  "C:/Users/<you>/AppData/Local/ai-chat-notify/bin/ai-chat-notify.ps1",
  "-ConfigPath",
  "C:/Users/<you>/AppData/Local/ai-chat-notify/config.json",
  "-LogPath",
  "C:/Users/<you>/AppData/Local/ai-chat-notify/ai-chat-notify.log",
  "-EventJson",
]
```

### 免安装（最简单，适合做 hook）
在仓库根目录直接运行：

```bat
.\ai-chat-notify.cmd -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details."
```

也可以显式调用脚本目录里的包装器：

```bat
.\scripts\ai-chat-notify.cmd -Title "Codex" -Subtitle "Turn complete" -Message "Check your CLI/IDE for details."
```

> 对 AI 产品集成（例如 Codex 的 `notify`）更推荐直接调用 `ai-chat-notify.ps1` 并使用 `-EventJson`：避免 `cmd.exe /c` 的二次解析把事件 JSON 的引号/反斜杠拆碎。

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

推荐优先级：

- AI 产品 hook/notify：`-EventJson`（由上游把事件 JSON 作为最后一个参数追加，最稳）
- 手动/脚本调用：`-EventFile` 或 `stdin`

### 1) `-EventJson`（推荐）

```powershell
$eventJson = Get-Content "./examples/codex-agent-turn-complete.json" -Raw
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  -EventJson $eventJson -Method "popup" -DurationSeconds 2 -NoSound
```

> Codex 的 `notify` 会在最后追加事件 JSON：配置器写入的 `notify` 会预先放一个 `-EventJson` 参数位，确保 PowerShell 正确绑定。

### 2) stdin（推荐：最好集成、最少转义）

```powershell
Get-Content "./examples/codex-agent-turn-complete.json" -Raw | powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  -Method "popup" -DurationSeconds 2 -NoSound
```

### 3) `-EventFile`

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  -EventFile "./examples/codex-agent-turn-complete.json" -Method "popup" -DurationSeconds 2 -NoSound
```

### 4) 位置参数（兼容；不推荐用于集成）
你可以把事件 JSON **作为第 1 个位置参数**传入：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/ai-chat-notify.ps1" `
  (Get-Content "./examples/codex-agent-turn-complete.json" -Raw)
```

### 推荐事件结构（通用）

`ai-chat-notify` 会优先读取这些字段（按需提供即可）。目前主要面向 **turn complete** 场景；其他类型字段先按通用结构保留，后续逐步增强。

```json
{
  "provider": "codex | claude-code | ...",
  "type": "agent-turn-complete | turn_complete | ...",
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

## 排障（Troubleshooting）

- `codex` 无法启动（config.toml parse error）：先检查 `config.toml` 的 `notify = [...]` 是否缺逗号/引号；如果是配置器写入导致，直接用配置器的“恢复最近备份”回滚。
- 对话结束不弹窗：确认已重启 `codex`；检查 `config.toml` 是否存在 `notify` 且末尾包含 `"-EventJson"`；用配置器点“检查 notify”确认是否匹配。
- 弹窗内容和配置器保存的不一致：确认 `notify` 里 `-ConfigPath` 指向的就是你保存的 `config.json`；修改配置后建议点“保存并写入 notify”同步（避免还在用旧路径）。
- 日志为空/没有生成：在配置器勾选“调试日志（-LogPath）”并写入 notify，重启 `codex` 后再触发一次；或临时设置环境变量 `AI_CHAT_NOTIFY_LOG`（兼容 `CODEX_NOTIFY_LOG`）。
- `balloon` 不显示：优先改用 `popup`（`balloon` 依赖系统通知/托盘能力与相关设置）。

## License

MIT
