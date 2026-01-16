# 配置隔离功能说明 (Configuration Isolation Feature)

## 问题描述

之前 Claude Code 和 Codex 共用同一套配置文件，导致调整一个提供者的配置时会影响另一个提供者。例如：
- 为 Codex 调整了窗口宽度为 400px
- Claude Code 的窗口宽度也跟着变成了 400px
- 无法为不同提供者设置独立的通知样式

## 解决方案

实现了**提供者级别的配置隔离**，现在每个提供者（Codex、Claude Code）可以有完全独立的通知配置。

## 配置文件结构变更

### 版本 1 (旧结构)
```json
{
  "version": 1,
  "defaults": {
    "provider": "codex",
    "title": "Codex",
    ...
  },
  "popup": {
    "width": 360,
    "height": 200,
    ...
  }
}
```

### 版本 2 (新结构)
```json
{
  "version": 2,
  "defaults": {
    "provider": "codex",
    "title": "AI Chat",
    ...
  },
  "providers": {
    "codex": {
      "title": "Codex",
      "subtitle": "任务已完成",
      "popup": {
        "width": 360,
        "height": 200,
        "accentColor": "#2B71D8",
        ...
      }
    },
    "claudecode": {
      "title": "Claude Code",
      "subtitle": "Task Complete",
      "popup": {
        "width": 400,
        "height": 180,
        "accentColor": "#7C3AED",
        ...
      }
    }
  },
  "popup": {
    "width": 360,
    ...
  }
}
```

## 关键特性

### 1. 提供者特定配置
- 每个提供者在 `providers` 节点下有独立配置
- 包含完整的通知设置：title, subtitle, message, popup样式等
- 修改一个提供者的配置不会影响其他提供者

### 2. 向后兼容
- 保留 `defaults` 和全局 `popup` 节点作为回退
- 自动检测配置版本并应用对应的读取逻辑
- 版本1配置会自动迁移到版本2

### 3. 自动迁移
- 配置器启动时自动检测版本1配置
- 自动迁移到版本2并保存
- 迁移时保留原有的所有设置
- 为两个提供者创建独立的初始配置

### 4. 配置器增强
- Provider 下拉框切换时自动加载对应配置
- 保存时只更新当前选中的提供者配置
- 保留其他提供者的配置不变

## 使用方法

### 方法1: 使用配置器 (推荐)

1. 运行配置器：
   ```powershell
   .\configurator.ps1
   ```

2. 在 "Provider" 下拉框中选择要配置的提供者（codex 或 claudecode）

3. 调整该提供者的通知样式（窗口大小、颜色、字体等）

4. 点击"保存"按钮

5. 切换到另一个提供者，配置不同的样式

6. 再次保存

现在两个提供者有完全独立的通知配置！

### 方法2: 手动编辑配置文件

编辑 `config.json`，在 `providers` 节点下为每个提供者设置独立配置：

```json
{
  "version": 2,
  "providers": {
    "codex": {
      "title": "Codex",
      "popup": {
        "width": 360,
        "accentColor": "#2B71D8"
      }
    },
    "claudecode": {
      "title": "Claude Code",
      "popup": {
        "width": 400,
        "accentColor": "#7C3AED"
      }
    }
  }
}
```

## 通知脚本变更

### `ai-chat-notify.ps1`
- 新增 `Get-ProviderConfig` 函数：读取提供者特定配置
- 新增 `Get-MergedPopupConfig` 函数：读取提供者特定的 popup 配置
- 通过环境变量 `AI_CHAT_NOTIFY_PROVIDER` 传递提供者信息给 inner 脚本

### `ai-chat-notify-inner.ps1`
- 新增 `Get-MergedPopupConfig` 函数
- 根据提供者读取对应的 popup 样式配置
- 优先使用提供者特定配置，回退到全局配置

## 配置优先级

1. **提供者特定配置** (providers.{provider}.popup)
2. **全局 popup 配置** (popup)
3. **硬编码的默认值**

例如，对于 Claude Code：
1. 首先检查 `providers.claudecode.popup`
2. 如果不存在，使用 `popup`
3. 如果都不存在，使用硬编码默认值

## 迁移逻辑

当检测到版本1配置时：

1. 读取原有的 `defaults` 和 `popup` 配置
2. 确定主要提供者（从 `defaults.provider`）
3. 将原有配置复制到该提供者的 `providers.{provider}` 节点
4. 为两个提供者创建初始配置
5. 更新版本号为 2
6. 自动保存迁移后的配置

**示例**：
```powershell
# 原版本1配置
{
  "version": 1,
  "defaults": {
    "provider": "codex",
    "title": "Codex"
  },
  "popup": {
    "width": 400
  }
}

# 自动迁移到版本2
{
  "version": 2,
  "providers": {
    "codex": {
      "title": "Codex",  # 保留原有设置
      "popup": {
        "width": 400     # 保留原有设置
      }
    },
    "claudecode": {
      "title": "Claude Code",  # 使用默认值
      "popup": {
        "width": 400           # 复制自原有配置
      }
    }
  }
}
```

## 测试

运行测试脚本验证配置隔离功能：

```powershell
.\test-config-isolation.ps1
```

测试内容：
- ✓ 创建版本2配置文件
- ✓ 验证提供者特定配置正确加载
- ✓ 验证不同提供者的配置相互独立
- ✓ 验证配置检索逻辑

## 文件清单

### 修改的文件
- `scripts/ai-chat-notify.ps1` - 主通知脚本
- `scripts/ai-chat-notify-inner.ps1` - UI渲染脚本
- `configurator.ps1` - 配置器

### 新增的文件
- `examples/config.sample.v2.json` - 版本2配置示例
- `test-config-isolation.ps1` - 配置隔离测试脚本
- `CONFIG-ISOLATION.md` - 本文档

## 常见问题 (FAQ)

**Q: 我的旧配置会丢失吗？**
A: 不会。配置器会自动检测并迁移版本1配置到版本2，保留所有原有设置。

**Q: 我可以继续使用版本1配置吗？**
A: 可以。通知脚本支持版本1和版本2配置，但建议使用版本2以获得配置隔离功能。

**Q: 如何回退到版本1配置？**
A: 不建议回退。如果确实需要，手动删除配置文件中的 `providers` 节点，并将版本号改为 1。

**Q: 我可以添加新的提供者吗？**
A: 可以。在 `providers` 节点下添加新的提供者配置即可，例如 `cursor`。

**Q: 配置器会修改所有提供者的配置吗？**
A: 不会。配置器只会更新当前选中 Provider 的配置，其他提供者的配置保持不变。

## 总结

配置隔离功能现在让你能够：
- ✅ 为 Codex 和 Claude Code 设置完全独立的通知样式
- ✅ 修改一个提供者的配置不影响另一个提供者
- ✅ 自动迁移旧配置，无需手动操作
- ✅ 使用配置器方便地管理每个提供者的配置
- ✅ 支持未来扩展更多提供者

享受完全隔离的通知配置体验！🎉
