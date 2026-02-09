# Beads (bd) 完全使用指南

> 分布式、基于 git 的问题追踪器，专为 AI 编码代理设计

---

## 目录

- [一、Beads 是什么？](#一beads-是什么)
- [二、为什么需要 Beads？](#二为什么需要-beads)
- [三、核心特性详解](#三核心特性详解)
- [四、安装与初始化](#四安装与初始化)
- [五、基础命令详解](#五基础命令详解)
- [六、高级用法](#六高级用法)
- [七、实际使用案例](#七实际使用案例)
- [八、与 AI 代理协作](#八与-ai-代理协作)
- [九、与其他工具对比](#九与其他工具对比)
- [十、最佳实践](#十最佳实践)
- [十一、常见问题](#十一常见问题)

---

## 一、Beads 是什么？

**Beads** 是一个**分布式、基于 git 的问题追踪器**，专为 **AI 编码代理**设计。它为 AI 代理提供持久化的结构化内存，替代混乱的 markdown 计划。

### 核心概念

```
传统方式：GitHub Issues / Jira / Trello
         ↓
    需要服务器、网络、复杂配置

Beads 方式：.beads/issues.jsonl
         ↓
    随代码走、git 原生、零基础设施
```

### 项目结构

```
your-project/
├── .beads/
│   ├── beads.db          # SQLite 数据库 (本地缓存，gitignore)
│   ├── issues.jsonl      # Git 追踪的源文件（真相来源）
│   └── config.yaml       # 配置文件
├── src/
└── README.md
```

---

## 二、为什么需要 Beads？

### 问题 1: AI 代理的"失忆"问题

```
❌ 没有 Beads：

你: "帮我实现用户认证功能"
AI: [写了登录页面...]
你: "继续"
AI: "抱歉，我不知道之前做到哪里了"

✅ 使用 Beads：

你: "bd create '实现用户认证' -p 1"
你: "请完成 bd ready 中的任务"
AI: [认领任务 → 工作 → 更新状态 → 完成]
你: "继续"
AI: [查看 bd ready，继续下一个任务]
```

### 问题 2: 复杂任务的依赖管理

```
场景：一个项目有 50+ 个任务
- 有些任务依赖其他任务
- 多个 AI 代理同时工作
- 需要追踪哪些任务可以开始、哪些被阻塞

Beads 解决方案：
✅ 自动计算可执行任务（bd ready）
✅ 依赖图可视化（bd dep tree）
✅ 哈希 ID 避免冲突
```

### 问题 3: 离线工作与协作

```
❌ GitHub Issues: 必须联网
✅ Beads: 完全离线，git push 时同步
```

---

## 三、核心特性详解

### 3.1 Git 原生存储

**JSONL 格式示例：**

```jsonl
{"id":"bd-a1b2","title":"实现用户注册","status":"open","priority":1,"created_at":"2026-02-09T12:00:00Z"}
{"id":"bd-c3d4","title":"数据库 schema","status":"in_progress","priority":0,"created_at":"2026-02-09T12:01:00Z"}
{"id":"bd-e5f6","title":"单元测试","status":"open","priority":2,"created_at":"2026-02-09T12:02:00Z"}
```

**为什么用 JSONL？**

| 特性 | JSON (单文件) | JSONL (一行一条) |
|------|--------------|-----------------|
| Git diff | ❌ 难以阅读 | ✅ 清晰可见 |
| 合并冲突 | ❌ 容易冲突 | ✅ 罕见冲突 |
| 人类可读 | ⚠️ 格式混乱 | ✅ 清晰 |
| 追加写入 | ❌ 需要重写 | ✅ 直接追加 |

### 3.2 基于哈希的 ID

**传统顺序 ID 的问题：**

```bash
# 开发者 A 在分支 feature-1
git checkout feature-1
bd create "添加 OAuth"  # → issue-10

# 开发者 B 在分支 feature-2
git checkout feature-2
bd create "添加 Stripe"  # → issue-10 (冲突！)

# 合并时出错
git merge feature-1  # 两个不同的 issue-10
```

**Beads 哈希 ID 解决方案：**

```bash
# 开发者 A
git checkout feature-1
bd create "添加 OAuth"  # → bd-x1y2 (从 UUID 哈希)

# 开发者 B
git checkout feature-2
bd create "添加 Stripe"  # → bd-z3w4 (不同哈希，无冲突!)

# 合并成功
git merge feature-1  # 清晰合并
```

**哈希长度自动扩展：**

```
0-500 个任务:    bd-a1b2     (4 字符)
500-1500 个任务:  bd-f14c3    (5 字符)
1500+ 个任务:     bd-3e7a5b   (6 字符)
```

### 3.3 依赖感知的任务图

**四种依赖类型：**

| 类型 | 含义 | 影响 `bd ready` | 示例 |
|------|------|----------------|------|
| `blocks` | 强阻塞 | ✅ 是 | 设计完成后才能编码 |
| `parent-child` | 父子关系 | ✅ 是 | 史诗和子任务 |
| `related` | 弱关联 | ❌ 否 | 相关问题参考 |
| `discovered-from` | 工作中发现 | ❌ 否 | 修复时发现的 bug |

**依赖图示例：**

```
bd-a1b2 (用户注册)
    │
    ├── [blocks] ──→ bd-c3d4 (数据库 schema)
    │                        │
    │                        └── [blocks] ──→ bd-x1y2 (安装 PostgreSQL)
    │
    ├── [blocks] ──→ bd-e5f6 (邮件服务)
    │
    └── [related] ──→ bd-z9w8 (忘记密码功能)

执行顺序：
1. bd-x1y2 (安装 PostgreSQL) - 无阻塞
2. bd-c3d4 (数据库 schema) - 等待 x1y2
3. bd-a1b2 (用户注册) - 等待 c3d4 和 e5f6
```

**自动计算可执行任务：**

```bash
$ bd ready
bd-x1y2 - 安装 PostgreSQL (priority: 0)
bd-e5f6 - 配置邮件服务 (priority: 1)

# 当 x1y2 完成后
$ bd ready
bd-e5f6 - 配置邮件服务 (priority: 1)
bd-c3d4 - 数据库 schema (priority: 0) ← 现在可执行了
```

### 3.4 三层数据模型

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLI 层                                   │
│                                                                  │
│  bd create, list, update, close, ready, show, dep, sync, ...    │
│  - 所有命令支持 --json 输出                                      │
│  - AI 代理友好的 API                                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               v
┌─────────────────────────────────────────────────────────────────┐
│                     SQLite 数据库                               │
│                     (.beads/beads.db)                           │
│                                                                  │
│  - 本地工作副本（gitignore）                                     │
│  - 快速查询（毫秒级）                                            │
│  - 索引、外键、全文搜索                                          │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                         自动同步
                         (5 秒防抖)
                               │
                               v
┌─────────────────────────────────────────────────────────────────┐
│                       JSONL 文件                                 │
│                   (.beads/issues.jsonl)                         │
│                                                                  │
│  - Git 追踪的真相来源                                            │
│  - 一行一个实体                                                  │
│  - 通过 git push/pull 分发                                       │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                          git push/pull
                               │
                               v
┌─────────────────────────────────────────────────────────────────┐
│                     远程仓库                                     │
│                    (GitHub / GitLab)                            │
│                                                                  │
│  - 存储在正常仓库历史中                                          │
│  - 所有协作者共享同一个问题数据库                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 四、安装与初始化

### 4.1 安装方式

**方式 1: 手动下载（推荐 Windows）**

```bash
# 下载并解压到 ~/bin
mkdir -p ~/bin
cd ~/bin
curl -L https://github.com/steveyegge/beads/releases/download/v0.49.6/beads_0.49.6_windows_amd64.zip -o beads.zip
unzip beads.zip
rm beads.zip

# 添加到 PATH
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bashrc
source ~/.bashrc

# 验证安装
bd --version
```

**方式 2: npm**

```bash
npm install -g @beads/bd
```

**方式 3: Go**

```bash
go install github.com/steveyegge/beads/cmd/bd@latest
```

**方式 4: Homebrew (macOS)**

```bash
brew install beads
```

### 4.2 初始化项目

```bash
# 进入你的项目目录
cd your-project

# 初始化 beads
bd init

# 输出：
# Initialized beads database in .beads/
# Run 'bd create' to create your first issue

# 查看状态
bd info
```

**初始化选项：**

```bash
# 标准初始化
bd init

# Stealth 模式（本地使用，不提交到 git）
bd init --stealth

# 贡献者模式（PR 到开源项目）
bd init --contributor

# 安装到独立分支
bd init --branch beads-metadata
```

### 4.3 目录结构

初始化后的项目结构：

```
your-project/
├── .beads/
│   ├── beads.db          # SQLite 数据库
│   ├── beads.db-shm      # WAL 共享内存
│   ├── beads.db-wal      # WAL 日志
│   ├── config.yaml       # 配置文件
│   └── issues.jsonl      # Git 追踪的问题文件
├── .git/
│   └── ...
└── src/
```

---

## 五、基础命令详解

### 5.1 创建任务

**基本语法：**

```bash
bd create "标题" [选项]
```

**常用选项：**

| 选项 | 说明 | 示例 |
|------|------|------|
| `-t, --type` | 任务类型 | `bug`, `feature`, `task`, `epic` |
| `-p, --priority` | 优先级 (0-4) | `0`=关键, `4`=backlog |
| `-d, --description` | 描述 | 详细说明 |
| `--design` | 设计文档 | 设计思路 |
| `--acceptance` | 验收标准 | 完成条件 |
| `--notes` | 备注信息 | 其他说明 |
| `--label, -l` | 标签 | 多个用逗号分隔 |
| `--parent` | 父任务 ID | 创建子任务 |
| `--deps` | 依赖任务 | `blocks:ID` 或 `discovered-from:ID` |
| `--assignee` | 指派给谁 | 用户/代理名称 |

**示例：**

```bash
# 1. 最简单的创建
bd create "修复登录 bug"
# → bd-a1b2

# 2. 带类型和优先级
bd create "实现用户注册" -t feature -p 1

# 3. 带描述
bd create "添加支付功能" -d "集成 Stripe 支付网关" -p 0

# 4. 带设计文档和验收标准
bd create "重构认证系统" \
  --design "使用 JWT 替代 Session" \
  --acceptance "1. 用户可以登录 2. Token 自动刷新 3. 支持登出" \
  -p 1

# 5. 带标签
bd create "优化查询性能" -l performance,urgent -p 0

# 6. 从文件读取描述
bd create "实现 API" --body-file api-spec.md

# 7. 创建史诗和子任务
bd create "支付系统" -t epic -p 1
# → bd-e5f6

bd create "Stripe 集成" --parent bd-e5f6 -p 1
# → bd-e5f6.1

bd create "支付宝集成" --parent bd-e5f6 -p 1
# → bd-e5f6.2

bd create "微信支付集成" --parent bd-e5f6 -p 1
# → bd-e5f6.3

# 8. 创建带依赖的任务
bd create "编写单元测试" --deps blocks:bd-a1b2
# 含义：bd-a1b2 完成后才能开始测试

# 9. AI 代理在工作中发现新问题
bd create "发现 API 兼容性问题" -t bug --deps discovered-from:bd-a1b2
# 含义：在处理 bd-a1b2 时发现的问题

# 10. 带外部引用
bd create "修复 GitHub issue #123" --external-ref "gh-123"
```

### 5.2 查看任务

**列出所有任务：**

```bash
bd list
```

**输出示例：**

```
bd-a1b2  ○  open    P1  feature  实现用户注册
bd-c3d4  ●  in_progress  P0  bug      修复登录超时
bd-e5f6  ○  open    P2  task     编写文档
bd-x1y2  ✓  closed  P1  feature  添加头像上传
```

**图例：**

| 符号 | 含义 |
|------|------|
| `○` | open |
| `◐` | in_progress |
| `●` | blocked |
| `✓` | closed |
| `❄` | deferred |

**过滤和搜索：**

```bash
# 按优先级
bd list --priority 0     # 只显示 P0
bd list --priority 0,1   # 显示 P0 和 P1

# 按状态
bd list --status open
bd list --status in_progress
bd list --status closed

# 按类型
bd list --type bug
bd list --type feature

# 搜索
bd list --search "登录"
bd list --search "API"

# 组合过滤
bd list --status open --priority 0 --type bug

# 限制数量
bd list --limit 10

# 按指派人
bd list --assignee agent-1
```

**查看可执行任务（最重要！）：**

```bash
# 查看没有阻塞的任务
bd ready

# 输出：
# bd-c3d4 - 修复登录超时 (priority: 0)
# bd-e5f6 - 编写文档 (priority: 2)

# JSON 输出（给 AI 用）
bd ready --json

# 输出：
# [
#   {
#     "id": "bd-c3d4",
#     "title": "修复登录超时",
#     "status": "open",
#     "priority": 0,
#     "type": "bug"
#   },
#   ...
# ]
```

**查看任务详情：**

```bash
# 查看单个任务
bd show bd-a1b2

# 查看多个任务
bd show bd-a1b2 bd-c3d4 bd-e5f6

# JSON 输出
bd show bd-a1b2 --json
```

**输出示例：**

```
bd-a1b2: 实现用户注册

Status:     open
Priority:   P1
Type:       feature
Assignee:   (unassigned)

Created:    2026-02-09 12:00:00
Updated:    2026-02-09 12:00:00

Description:
实现用户注册功能，包括：
- 邮箱注册
- 手机号注册
- 验证码验证

Design:
使用 JWT 进行认证...

Acceptance Criteria:
✓ 用户可以注册
✓ 验证码正确发送
✓ 防止重复注册

Dependencies:
  blocks: bd-c3d4 (数据库 schema)
  blocks: bd-e5f6 (邮件服务)

Labels:
  frontend, backend

Events:
  2026-02-09 12:00:00  Created
```

### 5.3 更新任务

**基本语法：**

```bash
bd update <id> [选项]
```

**常用选项：**

| 选项 | 说明 |
|------|------|
| `--title` | 修改标题 |
| `--status` | 修改状态 |
| `--priority` | 修改优先级 |
| `--assignee` | 指派给谁 |
| `--description` | 修改描述 |
| `--design` | 修改设计文档 |
| `--acceptance` | 修改验收标准 |
| `--notes` | 修改备注 |
| `--claim` | 原子认领（= status:in_progress + assignee:self） |
| `--spec-id` | 关联规范文档 |

**示例：**

```bash
# 1. 更新状态
bd update bd-a1b2 --status in_progress
bd update bd-a1b2 --status blocked
bd update bd-a1b2 --status closed

# 状态流转：
# open → in_progress → closed
#   ↘ blocked ↗

# 2. 更新优先级
bd update bd-a1b2 --priority 0

# 3. 指派任务
bd update bd-a1b2 --assignee developer-1

# 4. 原子认领（推荐！防止竞态条件）
bd update bd-a1b2 --claim
# 等价于：
# bd update bd-a1b2 --status in_progress --assignee $(whoami)
# 但是原子操作，如果已被别人认领会失败

# 5. 更新描述
bd update bd-a1b2 --description "新的描述内容"

# 6. 更新设计文档
bd update bd-a1b2 --design "使用 JWT + Redis"

# 7. 更新验收标准
bd update bd-a1b2 --acceptance "1. 登录成功 2. Token 有效期 7 天"

# 8. 添加备注
bd update bd-a1b2 --notes "注意处理并发登录"

# 9. 批量更新
bd update bd-a1b2 bd-c3d4 bd-e5f6 --status closed

# 10. JSON 输出
bd update bd-a1b2 --claim --json
```

### 5.4 关闭与重开任务

**关闭任务：**

```bash
# 基本关闭
bd close bd-a1b2

# 带原因
bd close bd-a1b2 --reason "已完成所有功能"

# 批量关闭
bd close bd-a1b2 bd-c3d4 --reason "不再需要"

# JSON 输出
bd close bd-a1b2 --reason "完成" --json
```

**重开任务：**

```bash
# 基本重开
bd reopen bd-a1b2

# 带原因
bd reopen bd-a1b2 --reason "发现新 bug，需要修复"
```

### 5.5 依赖关系管理

**添加依赖：**

```bash
# 基本语法
bd dep add <子任务> <父任务> [选项]

# 强阻塞（影响 ready）
bd dep add bd-a1b2 bd-c3d4 --type blocks
# 含义：bd-c3d4 必须完成，bd-a1b2 才能开始

# 父子关系
bd dep add bd-a1b2 bd-c3d4 --type parent-child
# 含义：bd-c3d4 是 bd-a1b2 的父任务

# 弱关联（不影响 ready）
bd dep add bd-a1b2 bd-c3d4 --type related
# 含义：两个任务相关，但互不阻塞

# 工作中发现
bd dep add bd-a1b2 bd-c3d4 --type discovered-from
# 含义：bd-a1b2 是在处理 bd-c3d4 时发现的

# 默认是 blocks
bd dep add bd-a1b2 bd-c3d4
# 等价于：bd dep add bd-a1b2 bd-c3d4 --type blocks
```

**删除依赖：**

```bash
bd dep remove bd-a1b2 bd-c3d4
```

**查看依赖树：**

```bash
# 查看某个任务的依赖树
bd dep tree bd-a1b2

# 输出示例：
# bd-a1b2: 实现用户注册
#   ├── [blocks] bd-c3d4: 数据库 schema
#   │   └── [blocks] bd-x1y2: 安装 PostgreSQL
#   ├── [blocks] bd-e5f6: 邮件服务
#   └── [related] bd-z9w8: 忘记密码功能
```

### 5.6 标签管理

**添加标签：**

```bash
# 单个标签
bd label add bd-a1b2 urgent

# 多个标签
bd label add bd-a1b2 frontend,backend

# 批量添加
bd label add bd-a1b2 bd-c3d4 urgent
```

**删除标签：**

```bash
# 删除单个标签
bd label remove bd-a1b2 urgent

# 批量删除
bd label remove bd-a1b2 bd-c3d4 urgent
```

**查看标签：**

```bash
# 查看任务的标签
bd label list bd-a1b2

# 查看所有标签
bd label list-all

# 输出：
# urgent (3 issues)
# frontend (5 issues)
# backend (7 issues)
```

---

## 六、高级用法

### 6.1 搜索与过滤

**高级搜索：**

```bash
# 按标题搜索
bd list --search "登录"

# 按描述搜索
bd list --search "API"

# 正则表达式
bd list --search "^实现.*功能"

# 组合条件
bd list --status open --priority 0 --type bug --search "安全"
```

**按指派人过滤：**

```bash
# 查看分配给某个人的任务
bd list --assignee developer-1

# 查看未分配的任务
bd list --unassigned

# 查看可执行的未分配任务
bd ready --unassigned
```

**按时间过滤：**

```bash
# 查看最近创建的任务
bd list --sort created --order desc

# 查看最近更新的任务
bd list --sort updated --order desc

# 查看陈旧任务（30 天未更新）
bd stale --days 30
```

### 6.2 配置管理

**查看配置：**

```bash
bd config get
```

**设置配置：**

```bash
# 设置同步分支
bd config set sync.branch beads-metadata

# 启用自动提交
bd config set sync.auto_commit true

# 启用自动推送
bd config set sync.auto_push true

# 设置问题前缀
bd config set issue.prefix myproj
# 结果：myproj-a1b2 而不是 bd-a1b2
```

**常用配置项：**

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `sync.branch` | 同步分支名 | 空（主分支） |
| `sync.auto_commit` | 自动提交 | false |
| `sync.auto_push` | 自动推送 | false |
| `issue.prefix` | 问题 ID 前缀 | bd |
| `core.editor` | 编辑器 | $EDITOR |
| `output.format` | 输出格式 | text |

### 6.3 导出与导入

**导出：**

```bash
# 导出到 JSONL
bd export -o backup.jsonl

# JSON 格式
bd export -o backup.jsonl --json

# 只导出开放的任务
bd export -o open.jsonl --status open
```

**导入：**

```bash
# 从 JSONL 导入
bd import -i backup.jsonl

# 合并模式
bd import -i backup.jsonl --merge

# 强制覆盖
bd import -i backup.jsonl --force
```

**只使用 JSONL（无数据库）：**

```bash
# 不使用 SQLite，只操作 JSONL
bd --no-db list
bd --no-db create "测试"
```

### 6.4 Stealth 模式

**本地使用，不提交到 git：**

```bash
# 初始化
bd init --stealth

# .beads/ 会被添加到 .gitignore
# 所有问题只在本地，不会推送到远程
```

**适用场景：**
- 个人实验性项目
- 不想公开的任务列表
- 共享项目中的私人待办

### 6.5 贡献者模式

**为开源项目贡献时使用：**

```bash
# 初始化
bd init --contributor

# 问题会被路由到独立仓库
# 例如：~/.beads-planning/your-fork/
# 保持主仓库干净，不包含 PR 规划
```

**工作流程：**

```bash
# 1. Fork 并克隆开源项目
git clone https://github.com/your-fork/open-source-project

# 2. 初始化贡献者模式
cd open-source-project
bd init --contributor

# 3. 创建任务
bd create "修复 bug #123" -p 1

# 4. 工作、提交 PR
# 5. 你的规划问题留在 ~/.beads-planning/，不会污染 PR
```

### 6.6 Git 工作流集成

**自动同步：**

```bash
# 修改任务后，5 秒自动导出到 JSONL
bd create "测试"

# .beads/issues.jsonl 自动更新

# Git 钩子自动提交（如果安装了钩子）
git status
# .beads/issues.jsonl 已暂存
```

**手动同步：**

```bash
# 导出、导入、提交
bd sync

# 等价于：
# bd export
# git add .beads/issues.jsonl
# git commit -m "Sync issues"
```

**安装 Git 钩子：**

```bash
# 安装钩子
bd hooks install

# 钩子会：
# - pre-commit: 自动导出问题到 JSONL
# - post-merge: 自动导入 JSONL 到数据库
```

**卸载钩子：**

```bash
bd hooks uninstall
```

### 6.7 查看审计日志

```bash
# 查看任务的所有变更历史
bd show bd-a1b2 --history

# 输出：
# Events:
#   2026-02-09 12:00:00  Created by user
#   2026-02-09 12:05:00  Status changed: open → in_progress
#   2026-02-09 12:10:00  Assignee changed: → developer-1
#   2026-02-09 12:15:00  Status changed: in_progress → closed
```

---

## 七、实际使用案例

### 案例 1: 个人项目管理

**场景：** 你要开发一个博客系统

```bash
# 1. 初始化
cd ~/my-blog
bd init

# 2. 规划任务
bd create "设计数据库" -p 0
# → bd-a1b2

bd create "实现后端 API" -p 1
# → bd-c3d4

bd create "前端页面" -p 1
# → bd-e5f6

bd create "编写测试" -p 2
# → bd-x1y2

bd create "部署上线" -p 3
# → bd-z9w8

# 3. 设置依赖
bd dep add bd-c3d4 bd-a1b2  # API 依赖数据库
bd dep add bd-e5f6 bd-a1b2  # 前端依赖数据库
bd dep add bd-x1y2 bd-c3d4  # 测试依赖 API
bd dep add bd-z9w8 bd-x1y2  # 部署依赖测试

# 4. 查看今天要做什么
bd ready
# bd-a1b2 - 设计数据库 (priority: 0)

# 5. 开始工作
bd update bd-a1b2 --claim

# 6. 完成后继续
bd close bd-a1b2 --reason '完成'
bd ready
# bd-c3d4 - 实现后端 API (priority: 1)
# bd-e5f6 - 前端页面 (priority: 1)
```

### 案例 2: Bug 修复流程

**场景：** 生产环境发现了一个严重 bug

```bash
# 1. 创建 P0 bug
bd create "支付接口超时导致订单丢失" -t bug -p 0
# → bd-critical-1

# 2. 认领并开始调查
bd update bd-critical-1 --claim
bd update bd-critical-1 --status in_progress

# 3. 调查中发现更多问题
bd create "数据库连接池配置错误" -t bug --deps discovered-from:bd-critical-1
# → bd-critical-2

bd create "缺少重试机制" -t bug --deps discovered-from:bd-critical-1
# → bd-critical-3

# 4. 查看依赖树
bd dep tree bd-critical-1
# bd-critical-1: 支付接口超时
#   ├── [discovered-from] bd-critical-2: 数据库连接池
#   └── [discovered-from] bd-critical-3: 缺少重试

# 5. 按顺序修复
bd ready
# bd-critical-2, bd-critical-3 可执行

bd update bd-critical-2 --claim
# [修复...]
bd close bd-critical-2

bd update bd-critical-3 --claim
# [修复...]
bd close bd-critical-3

# 6. 完成主问题
bd close bd-critical-1 --reason '所有相关问题已修复'

# 7. 同步到团队
git push
```

### 案例 3: 功能开发（史诗）

**场景：** 开发一个完整的用户认证系统

```bash
# 1. 创建史诗
bd create "用户认证系统" -t epic -p 1 \
  --description "实现完整的用户认证功能" \
  --acceptance "1. 注册 2. 登录 3. 登出 4. 密码重置"
# → bd-auth-epic

# 2. 创建子任务
bd create "数据库设计" -p 0 --parent bd-auth-epic
# → bd-auth-epic.1

bd create "注册 API" -p 1 --parent bd-auth-epic
# → bd-auth-epic.2

bd create "登录 API" -p 1 --parent bd-auth-epic
# → bd-auth-epic.3

bd create "Token 管理" -p 1 --parent bd-auth-epic
# → bd-auth-epic.4

bd create "密码重置" -p 2 --parent bd-auth-epic
# → bd-auth-epic.5

bd create "前端登录页" -p 2 --parent bd-auth-epic
# → bd-auth-epic.6

bd create "前端注册页" -p 2 --parent bd-auth-epic
# → bd-auth-epic.7

# 3. 设置依赖
bd dep add bd-auth-epic.2 bd-auth-epic.1
bd dep add bd-auth-epic.3 bd-auth-epic.1
bd dep add bd-auth-epic.4 bd-auth-epic.2
bd dep add bd-auth-epic.4 bd-auth-epic.3
bd dep add bd-auth-epic.5 bd-auth-epic.3
bd dep add bd-auth-epic.6 bd-auth-epic.3
bd dep add bd-auth-epic.6 bd-auth-epic.4
bd dep add bd-auth-epic.7 bd-auth-epic.2

# 4. 查看执行计划
bd dep tree bd-auth-epic
# bd-auth-epic: 用户认证系统
#   ├── bd-auth-epic.1: 数据库设计
#   ├── bd-auth-epic.2: 注册 API (依赖: .1)
#   ├── bd-auth-epic.3: 登录 API (依赖: .1)
#   ├── bd-auth-epic.4: Token 管理 (依赖: .2, .3)
#   ├── bd-auth-epic.5: 密码重置 (依赖: .3)
#   ├── bd-auth-epic.6: 前端登录页 (依赖: .3, .4)
#   └── bd-auth-epic.7: 前端注册页 (依赖: .2)

# 5. 开始执行
bd ready
# bd-auth-epic.1 - 数据库设计
```

### 案例 4: 代码审查清单

```bash
# 创建代码审查任务
bd create "审查 PR #123" -t chore -p 1 \
  --acceptance "
  1. 代码风格符合规范
  2. 没有安全漏洞
  3. 测试覆盖率足够
  4. 文档已更新
  " \
  --notes "关注 SQL 注入风险"

# 开始审查
bd update bd-a1b2 --claim

# 发现问题，创建子任务
bd create "添加输入验证" -t bug --deps discovered-from:bd-a1b2
bd create "添加单元测试" -t task --deps discovered-from:bd-a1b2

# 审查通过
bd close bd-a1b2 --reason "LGTM，已创建后续任务"
```

---

## 八、与 AI 代理协作

### 8.1 AI 代理工作流

**标准流程：**

```bash
# 1. AI 查看可执行任务
bd ready --json

# 输出：
# [
#   {
#     "id": "bd-a1b2",
#     "title": "实现用户注册",
#     "status": "open",
#     "priority": 1,
#     "type": "feature",
#     "description": "...",
#     "acceptance_criteria": "..."
#   }
# ]

# 2. AI 认领任务
bd update bd-a1b2 --claim --json

# 3. AI 开始工作
# [编写代码...]

# 4. 工作中发现新问题
bd create "发现 API 兼容性问题" \
  -t bug \
  --description "在实现过程中发现..." \
  --deps discovered-from:bd-a1b2 \
  --json

# 5. 完成任务
bd close bd-a1b2 --reason "实现完成，包含单元测试" --json

# 6. 同步
bd sync
git push
```

### 8.2 与 Claude Code 协作

**提示词模板：**

```
请完成 bd ready 中的第一个任务。步骤：
1. 运行 bd ready --json 查看任务
2. 认领任务：bd update <id> --claim
3. 实现功能
4. 关闭任务：bd close <id> --reason "说明"
5. 如果发现新问题，使用 --deps discovered-from:<parent-id>
```

**完整会话示例：**

```
你: 请帮我实现这个项目的 TODO

AI: 让我先查看可执行任务...

[运行: bd ready --json]

AI: 我看到以下可执行任务：
- bd-a1b2: 实现用户注册 (P1)
- bd-c3d4: 配置数据库 (P0)

我先处理 P0 的数据库配置。

[运行: bd update bd-c3d4 --claim]

AI: 已认领任务，开始配置数据库...

[编写代码...]

AI: 数据库配置完成。

[运行: bd close bd-c3d4 --reason "完成 PostgreSQL 配置"]

AI: 任务完成！继续下一个任务...

[运行: bd ready --json]
```

### 8.3 多代理协作

**场景：** 两个 AI 代理同时工作

```bash
# Agent 1 处理前端
bd create "实现登录页面" -l frontend --assignee agent-1
bd update bd-a1b2 --claim --assignee agent-1

# Agent 2 处理后端
bd create "实现登录 API" -l backend --assignee agent-2
bd update bd-c3d4 --claim --assignee agent-2

# 查看各自的任务
bd list --assignee agent-1
bd list --assignee agent-2

# 查看所有可执行任务
bd ready
```

---

## 九、与其他工具对比

### 9.1 功能对比表

| 特性 | Beads | GitHub Issues | Jira | Linear | Trello |
|------|-------|--------------|------|--------|-------|
| **离线工作** | ✅ 完全离线 | ❌ 需要网络 | ❌ 需要网络 | ❌ 需要网络 | ❌ 需要网络 |
| **Git 集成** | ✅ 原生 | ⚠️ 需要配置 | ❌ 无 | ⚠️ 有限 | ❌ 无 |
| **依赖关系** | ✅ 4 种类型 | ⚠️ 只有 blocked | ✅ 复杂 | ✅ 简单 | ❌ 无 |
| **AI 友好** | ✅ JSON 优先 | ⚠️ 混合输出 | ❌ 企业级 | ⚠️ 有限 | ❌ 无 |
| **无服务器** | ✅ 零基础设施 | ❌ 需要 GitHub | ❌ 需要服务器 | ❌ 需要 SaaS | ❌ 需要 SaaS |
| **零配置** | ✅ 开箱即用 | ⚠️ 需要 token | ❌ 复杂配置 | ⚠️ 需要 workspace | ⚠️ 需要登录 |
| **分支隔离** | ✅ 问题在分支上 | ❌ 全局仓库 | ❌ 全局 | ❌ 全局 | ❌ 全局 |
| **合并安全** | ✅ 哈希 ID | ⚠️ 顺序 ID | ⚠️ 顺序 ID | ⚠️ 顺序 ID | N/A |
| **本地数据库** | ✅ SQLite | ❌ 仅 API | ❌ 仅 API | ❌ 仅 API | ❌ 仅 API |
| **查询速度** | ✅ 毫秒级 | ⚠️ 取决网络 | ⚠️ 取决网络 | ⚠️ 取决网络 | ⚠️ 取决网络 |
| **价格** | ✅ 免费 | ✅ 免费 | ❌ 昂贵 | ❌ 昂贵 | ⚠️ 有限免费 |

### 9.2 使用场景建议

**使用 Beads：**
- ✅ AI 辅助开发
- ✅ 个人项目
- ✅ 小团队（<10 人）
- ✅ 需要离线工作
- ✅ Git 原生工作流
- ✅ 开源项目贡献

**使用 GitHub Issues：**
- ✅ 大型开源项目
- ✅ 需要社区参与
- ✅ 复杂的 PR 管理
- ✅ 跨仓库讨论

**使用 Jira：**
- ✅ 大型企业团队
- ✅ 需要复杂报表
- ✅ Scrum/Agile 流程
- ✅ 多部门协作

**使用 Linear：**
- ✅ 现代化界面
- ✅ 快速成长团队
- ✅ 需要良好 UX

**使用 Trello：**
- ✅ 简单看板
- ✅ 非技术团队
- ✅ 轻量级项目

---

## 十、最佳实践

### 10.1 优先级指南

```bash
P0 (0) - 关键路径
  ├─ 阻塞其他人的任务
  ├─ 生产环境 bug
  └─ 安全漏洞

P1 (1) - 高优先级
  ├─ 当前迭代的核心功能
  └─ 重要但不紧急

P2 (2) - 正常优先级
  ├─ 常规功能开发
  └─ 性能优化

P3 (3) - 低优先级
  ├─ 改进型任务
  └─ 技术债务

P4 (4) - Backlog
  ├─ 想法收集
  └─ 将来可能做的
```

### 10.2 任务类型指南

| 类型 | 使用场景 | 示例 |
|------|---------|------|
| `bug` | 错误修复 | "登录失败" |
| `feature` | 新功能 | "添加头像上传" |
| `task` | 普通任务 | "更新文档" |
| `epic` | 大型任务 | "支付系统" |
| `chore` | 杂项 | "升级依赖版本" |
| `message` | 临时消息 | "会议纪要" |

### 10.3 命名规范

**好的任务标题：**

```bash
✅ "实现用户注册功能"
✅ "修复登录超时 bug"
✅ "优化数据库查询性能"
✅ "添加 API 文档"

❌ "注册"
❌ "有 bug"
❌ "性能"
❌ "文档"
```

**模板：**

```
动词 + 对象 + 补充说明

动词：
- 实现、修复、优化、重构、添加、删除、更新

对象：
- 用户注册、登录、API、数据库、前端、后端

补充说明：
- 支持微信登录、修复超时问题、提升 50% 性能
```

### 10.4 描述写作指南

**好的描述：**

```
## 背景
用户反馈在移动端登录时经常超时

## 问题
当前超时设置为 5 秒，移动网络环境可能需要更长时间

## 方案
1. 将超时时间调整为 30 秒
2. 添加重试机制
3. 显示友好错误提示

## 验收
- [ ] 4G 网络下可以正常登录
- [ ] 超时后会自动重试
- [ ] 显示明确的错误提示
```

### 10.5 依赖关系最佳实践

**何时使用 blocks：**

```bash
# 编码依赖设计
bd dep add feature-xxx design-doc --type blocks

# 测试依赖实现
bd dep add tests-xxx feature-xxx --type blocks

# 部署依赖测试
bd dep add deploy-xxx tests-xxx --type blocks
```

**何时使用 related：**

```bash
# 相关问题参考
bd dep add fix-ssl fix-tls --type related

# 跨功能参考
bd dep add web-api mobile-api --type related
```

**何时使用 discovered-from：**

```bash
# 工作中发现的 bug
bd create "发现 SQL 注入" -t bug --deps discovered-from:bd-a1b2

# 工作中发现的新功能
bd create "添加批量导入" -t feature --deps discovered-from:bd-a1b2
```

### 10.6 团队协作建议

**1. 使用指派字段：**

```bash
# 明确责任
bd update bd-a1b2 --assignee alice
bd update bd-c3d4 --assignee bob
```

**2. 定期同步：**

```bash
# 每日同步
git pull
bd ready
git push

# 周会准备
bd list --status in_progress
bd list --assignee $(whoami)
```

**3. 使用标签分类：**

```bash
# 按团队
bd label add bd-a1b2 team-frontend
bd label add bd-c3d4 team-backend

# 按复杂度
bd label add bd-a1b2 complex
bd label add bd-c3d4 simple

# 按冲刺
bd label add bd-a1b2 sprint-2024-w32
```

### 10.7 Git 工作流集成

**推荐流程：**

```bash
# 1. 开始任务前
git checkout -b feature/bd-a1b2-user-auth
bd update bd-a1b2 --claim

# 2. 开发过程中
# [编写代码...]
bd create "发现需要加密库" -t chore --deps discovered-from:bd-a1b2

# 3. 完成任务
git add .
bd close bd-a1b2 --reason "实现完成，包含测试"
git commit -m "完成用户认证 (bd-a1b2)"

# 4. 提交 PR
git push
# 创建 PR: "feat: 用户认证系统 (fixes bd-a1b2)"

# 5. 代码审查
# [审查通过]

# 6. 合并
git checkout main
git merge feature/bd-a1b2-user-auth
git push
```

### 10.8 大型项目建议

**拆分数据库：**

```bash
# 按组件拆分
cd project/frontend && bd init --prefix fe
cd project/backend && bd init --prefix be
cd project/mobile && bd init --prefix mb

# 或者按团队拆分
cd ~/team-a/project && bd init --prefix tea
cd ~/team-b/project && bd init --prefix teb
```

**使用独立分支：**

```bash
# 避免污染主分支
bd init --branch beads-metadata

# 工作流
git checkout main  # 正常开发
git checkout beads-metadata  # 问题追踪
```

---

## 十一、常见问题

### Q1: Beads 和 GitHub Issues 有什么区别？

**A:**

| 方面 | Beads | GitHub Issues |
|------|-------|--------------|
| 存储位置 | 本地 .beads/ | GitHub 服务器 |
| 离线工作 | ✅ 支持 | ❌ 不支持 |
| 分支隔离 | ✅ 每个分支独立 | ❌ 全局共享 |
| ID 冲突 | ✅ 哈希 ID 无冲突 | ⚠️ 顺序 ID 可能冲突 |
| AI 友好 | ✅ JSON 输出 | ⚠️ 混合输出 |
| 查询速度 | ✅ 本地毫秒级 | ⚠️ 取决网络 |
| 依赖关系 | ✅ 4 种类型 | ⚠️ 只有 blocked |

### Q2: 可以在同一个项目混用 Beads 和 GitHub Issues 吗？

**A:** 可以，但不推荐。

```bash
# Beads 用于：
- 开发过程中的任务管理
- AI 代理协作
- 本地离线工作

# GitHub Issues 用于：
- 用户反馈
- Bug 报告
- 功能请求（外部）
```

### Q3: 如何迁移现有的 GitHub Issues 到 Beads？

**A:** 暂无自动迁移工具，但可以手动导出：

```bash
# 1. 使用 GitHub CLI 导出
gh issue list --json number,title,body,state > issues.json

# 2. 编写脚本转换
# (将 GitHub Issues 格式转换为 Beads JSONL)

# 3. 导入到 Beads
bd import -i converted.jsonl
```

### Q4: Beads 的数据安全吗？

**A:** 是的，原因：

1. **Git 版本控制**: 所有历史都有记录
2. **JSONL 格式**: 人类可读，易于恢复
3. **本地数据库**: SQLite 可靠，损坏可从 JSONL 恢复
4. **开源**: 代码透明，可审计

### Q5: 如何处理合并冲突？

**A:** JSONL 格式极少冲突，如果发生：

```bash
# 1. 查看冲突
git status
# .beads/issues.jsonl: both modified

# 2. 查看冲突内容
git diff .beads/issues.jsonl

# 3. 手动合并（通常是保留两行）
# 由于每行是一个独立 issue，冲突通常只是添加顺序问题

# 4. 重新导入
bd import -i .beads/issues.jsonl

# 5. 提交
git add .beads/issues.jsonl
git commit
```

### Q6: 可以在非 Git 项目中使用 Beads 吗？

**A:** 可以，但会失去同步功能。

```bash
# 初始化
bd init

# 正常使用
bd create "任务"
bd list
bd ready

# 注意：
# - 无法通过 git 同步
# - 需要手动备份 .beads/ 目录
# - 团队协作困难
```

### Q7: Beads 的性能如何？

**A:** 非常好：

| 操作 | 时间 |
|------|------|
| 创建任务 | ~10ms |
| 查询任务 | ~5ms |
| 依赖计算 | ~10ms |
| 列出 1000 个任务 | ~50ms |
| 导出/导入 | ~100ms |

**支持规模：**
- 10,000+ 个任务
- 100+ 人团队
- 复杂依赖图

### Q8: 如何备份 Beads 数据？

**A:** 多种方式：

```bash
# 方式 1: Git 自动备份（推荐）
git push

# 方式 2: 导出备份
bd export -o backup-$(date +%Y%m%d).jsonl

# 方式 3: 备份整个目录
cp -r .beads .beads.backup.$(date +%Y%m%d)
```

### Q9: Beads 支持多语言吗？

**A:** 界面语言英文，但：

```bash
# 可以用中文创建任务
bd create "实现用户注册功能"
bd create "修复登录超时问题"

# 支持中文搜索
bd list --search "用户"
bd list --search "登录"
```

### Q10: 如何给 Beads 项目贡献代码？

**A:**

```bash
# 1. Fork 并克隆
git clone https://github.com/your-username/beads

# 2. 初始化贡献者模式
cd beads
bd init --contributor

# 3. 创建任务
bd create "添加新功能" -p 1

# 4. 开发、测试、提交 PR
```

### Q11: Beads 适合什么规模的项目？

**A:**

| 项目规模 | 是否适合 | 说明 |
|---------|---------|------|
| 个人项目 | ✅ 完美 | 零配置，开箱即用 |
| 小团队（2-10人） | ✅ 推荐 | 简单高效 |
| 中型团队（10-50人） | ✅ 可用 | 需要规范流程 |
| 大型团队（50+人） | ⚠️ 谨慎 | 可能需要 Jira 等企业工具 |

### Q12: 如何在 CI/CD 中使用 Beads？

**A:** 示例：

```yaml
# .github/workflows/check-issues.yml
name: Check Beads Issues

on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install Beads
        run: |
          curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

      - name: Check for P0 issues
        run: |
          bd list --priority 0 --status open > p0-issues.txt
          if [ -s p0-issues.txt ]; then
            echo "⚠️  Found P0 issues:"
            cat p0-issues.txt
            exit 1
          fi
```

---

## 十二、快速参考

### 常用命令速查

```bash
# 初始化
bd init

# 创建任务
bd create "标题" -t <类型> -p <优先级>
bd create "实现登录" -t feature -p 0

# 查看任务
bd list                    # 所有任务
bd ready                   # 可执行任务（重要！）
bd show <id>               # 任务详情

# 更新任务
bd update <id> --claim                      # 认领
bd update <id> --status in_progress         # 更新状态
bd update <id> --priority 0                 # 更新优先级

# 关闭/重开
bd close <id> --reason "完成"
bd reopen <id> --reason "需要继续"

# 依赖关系
bd dep add <子> <父>                       # 添加依赖
bd dep tree <id>                           # 查看依赖树

# 标签
bd label add <id> <标签>
bd label remove <id> <标签>

# 同步
bd sync                                     # 手动同步
git push                                   # 推送到远程

# JSON 输出（AI 使用）
bd ready --json
bd show <id> --json
```

### 优先级速查

```bash
-p 0  # P0: 关键路径（阻塞其他人）
-p 1  # P1: 高优先级
-p 2  # P2: 正常优先级
-p 3  # P3: 低优先级
-p 4  # P4: Backlog
```

### 任务类型速查

```bash
-t bug      # Bug 修复
-t feature  # 新功能
-t task     # 普通任务
-t epic     # 史诗（大任务）
-t chore    # 杂项
```

### 状态速查

```bash
--status open          # 开放
--status in_progress   # 进行中
--status blocked       # 被阻塞
--status deferred      # 延期
--status closed        # 已关闭
```

---

## 总结

**Beads 的核心价值：**

1. **简单**: 零配置，开箱即用
2. **强大**: 依赖图、哈希 ID、自动同步
3. **AI 友好**: JSON 优先，所有命令都有 --json
4. **Git 原生**: 随代码走，零基础设施
5. **离线优先**: 完全离线工作

**开始使用：**

```bash
# 1. 安装（已完成）
# 2. 初始化项目
cd your-project
bd init

# 3. 创建第一个任务
bd create "我的第一个任务" -p 1

# 4. 查看可执行任务
bd ready

# 5. 开始工作！
```

---

**更多信息：**

- GitHub: https://github.com/steveyegge/beads
- 文档: https://github.com/steveyegge/beads/tree/main/docs
- 讨论: https://github.com/steveyegge/beads/discussions
- 问题报告: https://github.com/steveyegge/beads/issues

---

*最后更新: 2026-02-09*
*Beads 版本: 0.49.6*
