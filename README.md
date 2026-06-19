# Compound Engineering System

> "每一次工程工作都应该让后续工作变得更容易——而不是更难。" — CE Plugin Philosophy

跨平台的 Compound Engineering System，支持 Claude Code、Cursor、Windsurf、GitHub Copilot、Aider 等主流 AI 编程工具。核心：任务后自动反思 + 错误提取 + 知识积累。

## Features

- **多平台支持**：Claude Code / Cursor / Windsurf / GitHub Copilot / Aider / Hermes / Codex
- **三级成本过滤**：Level 0 规则门（零成本）→ Level 1 Quick Reflect（~$0.0002）→ Level 2 Deep Reflect（~$0.03）
- **三层记忆结构**：Working（工作记忆）→ Session（短期记忆）→ Longterm（长期记忆），知识有时间维度
- **文件级存储**：Markdown + YAML frontmatter，支持 grep 零成本预过滤
- **双轨制**：Bug Track（错误排查）+ Knowledge Track（架构决策/最佳实践）
- **任务断点恢复**：Checkpoint 系统，复杂任务中断后可从断点继续
- **多 LLM 支持**：DeepSeek / OpenAI / 小米 MIMO / Anthropic / 自定义 API
- **生命周期管理**：定期检查文档是否过期，自动归档

## Quick Start

```bash
# 1. Clone or copy to your system
git clone https://github.com/lennney/compound-system.git
cd compound-system

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Configure LLM API (interactive wizard)
bash scripts/setup.sh

# 4. Initialize for your platform
bash scripts/init-platform.sh claude-code  # or cursor, copilot, aider, all

# 5. After a task, run reflection
scripts/compound.sh --task "your task description" --status "success|partial|failed"

# 6. Before a task, search solutions
scripts/search.sh "error description"
```

## Multi-Platform Support

### Supported Platforms

| Platform | Adapter | Configuration |
|----------|---------|---------------|
| **Claude Code** | `CLAUDE-compound.md` | `init-platform.sh claude-code` |
| **Cursor** | `.cursor/rules-compound.md` | `init-platform.sh cursor` |
| **Windsurf** | `.cursor/rules-compound.md` | `init-platform.sh cursor` |
| **GitHub Copilot** | `.github/copilot-instructions.md` | `init-platform.sh copilot` |
| **Aider** | `.aider.conf.yml` | `init-platform.sh aider` |
| **Hermes** | `platforms/hermes/SKILL.md` | Manual copy |
| **Codex** | `platforms/codex/codex.md` | Manual copy |

### Quick Platform Setup

```bash
# Initialize for specific platform
bash scripts/init-platform.sh claude-code
bash scripts/init-platform.sh cursor
bash scripts/init-platform.sh copilot
bash scripts/init-platform.sh aider

# Initialize for all platforms
bash scripts/init-platform.sh all

# Generate to global directory
bash scripts/init-platform.sh claude-code --global
```

### Supported LLM Providers

| Provider | Endpoint | Model |
|----------|----------|-------|
| **DeepSeek** | `https://api.deepseek.com/v1` | `deepseek-chat` |
| **OpenAI** | `https://api.openai.com/v1` | `gpt-4o-mini` |
| **小米 MIMO (Token Plan)** | `https://token-plan-cn.xiaomimimo.com/v1` | `mimo-v2.5` |
| **小米 MIMO (SK)** | `https://api.xiaomimimo.com/v1` | `mimo-v2.5` |
| **Anthropic** | `https://api.anthropic.com/v1` | `claude-3-haiku-20240307` |
| **Custom** | Your endpoint | Your model |

### LLM Configuration

```bash
# Interactive setup wizard (recommended)
bash scripts/setup.sh

# Non-interactive setup
LLM_API_KEY=your-key bash scripts/setup.sh --provider deepseek

# Test current configuration
bash scripts/setup.sh --test

# Show current configuration
bash scripts/setup.sh --show
```

## Directory Structure

```
compound-system/
├── solutions/              # 知识库（三层记忆）
│   ├── working/            # 工作记忆（临时，1天后自动归档）
│   ├── session/            # 短期记忆（跨session，90天过期）
│   │   ├── bugs/           # 错误模式 & 修复
│   │   └── knowledge/      # 架构决策 & 最佳实践
│   ├── longterm/           # 长期记忆（永久保留）
│   │   └── patterns/       # 提炼出的通用模式
│   ├── CONCEPTS.md         # 自动维护的词汇表
│   └── .archive/           # 归档（从 session/working 过期来的）
├── .checkpoints/           # 任务断点（独立于 solutions）
│   └── <task-id>.json      # 每个任务一个 checkpoint
├── scripts/                # 核心脚本
│   ├── compound.sh         # 主入口
│   ├── reflect.sh          # LLM 驱动的反思
│   ├── search.sh           # 搜索知识库
│   ├── write-solution.sh   # 写入解决方案
│   ├── promote.sh          # 晋升知识层级（working → session → longterm）
│   ├── checkpoint.sh       # 任务断点管理
│   ├── refresh.sh          # 生命周期管理
│   └── utils.sh            # 共享函数
├── templates/              # 解决方案模板
├── platforms/              # 平台适配器
│   ├── hermes/SKILL.md
│   ├── claude-code/CLAUDE.md
│   └── codex/codex.md
├── tests/                  # 测试套件
└── docs/                   # 文档
```

## Memory Tiers

系统采用三层记忆结构，让知识有时间维度，避免扁平膨胀：

| Tier | 目录 | 用途 | 生命周期 | 说明 |
|------|------|------|----------|------|
| **Working** | `solutions/working/` | 工作记忆 | 1天自动归档 | 调试过程中的临时发现、中间产物 |
| **Session** | `solutions/session/` | 短期记忆 | 90天过期 | 跨 session 有效的 bug 和知识 |
| **Longterm** | `solutions/longterm/` | 长期记忆 | 永久保留 | 提炼出的通用模式和最佳实践 |

### 知识晋升

使用 `promote.sh` 将知识从低层级提升到高层级：

```bash
# 临时发现有价值 → 晋升到 session
scripts/promote.sh solutions/working/discovery.md session

# session 中的知识被验证多次 → 晋升到 longterm
scripts/promote.sh solutions/session/bugs/common-error.md longterm
```

晋升时如果目标文件已存在，会合并 `occurrence_count` 并删除源文件。

### 搜索范围

搜索时自动遍历三层（从浅到深），结果标注来源层级：

- `[工作记忆]` — 来自 working/
- `[短期记忆]` — 来自 session/
- `[长期记忆]` — 来自 longterm/

```bash
# 搜索全部三层
scripts/search.sh "401 error"

# 只搜 bug 相关（working + session/bugs）
scripts/search.sh "timeout" --track bug
```

## Checkpoint System

复杂任务中断后可从断点继续，避免重复劳动。

### Checkpoint 结构

```json
{
  "task_id": "debug-ticketpilot",
  "phase": "phase2",
  "completed_steps": ["check-logs", "identify-error"],
  "pending_steps": ["fix-db", "test", "deploy"],
  "context": {"pr": "123"},
  "created_at": "2026-06-16T10:00:00Z",
  "updated_at": "2026-06-16T10:15:00Z"
}
```

### 使用方法

```bash
# 保存断点
scripts/checkpoint.sh save "debug-ticketpilot" "phase2" \
  '["check-logs","identify-error"]' \
  '["fix-db","test","deploy"]' \
  '{"pr":"123"}'

# 查看所有活跃断点
scripts/checkpoint.sh list
# 输出：debug-ticketpilot | phase=phase2 | done=2 | pending=3 | updated=2026-06-16T...

# 加载断点，从上次中断处继续
scripts/checkpoint.sh load "debug-ticketpilot" | jq '.completed_steps'
# ["check-logs","identify-error"]

# 完成后清除
scripts/checkpoint.sh clear "debug-ticketpilot"

# 检查断点是否存在
scripts/checkpoint.sh exists "debug-ticketpilot"
# true / false
```

也可以通过 compound.sh 统一入口：

```bash
scripts/compound.sh checkpoint save "my-task" "phase1" '["s1"]' '["s2"]'
scripts/compound.sh checkpoint list
scripts/compound.sh checkpoint load "my-task"
scripts/compound.sh checkpoint clear "my-task"
```

### 典型场景

**调试中断恢复**：
```bash
# 开始调试，每完成一步保存 checkpoint
compound.sh checkpoint save "debug-e2e" "phase1" \
  '["check-logs","find-error"]' '["fix-db","test"]'

# subagent 被中断... 下次启动时检查
compound.sh checkpoint list
compound.sh checkpoint load "debug-e2e" | jq '.completed_steps'
# 直接从断点继续，跳过已完成步骤

# 完成后清除
compound.sh checkpoint clear "debug-e2e"
```

## Cost Optimization

| Level | Trigger | Cost | Savings |
|-------|---------|------|---------|
| Skip | Simple tasks | $0 | 100% |
| Quick | Errors, complexity | ~$0.0002 | 85-99% |
| Deep | Critical, cross-domain | ~$0.03 | 0% (full cost) |

**Rule Gate** (Level 0) filters out 40-50% of unnecessary LLM calls at zero cost.

## Platform Adapters

### Automatic Setup (Recommended)

```bash
# Initialize for your platform
bash scripts/init-platform.sh <platform>

# Available platforms:
#   claude-code  - Claude Code
#   cursor       - Cursor / Windsurf
#   copilot      - GitHub Copilot
#   aider        - Aider
#   all          - All platforms
#   conventions  - Generic conventions file
#   hooks        - Generate hooks config
```

### Manual Setup

#### Claude Code
```bash
# Copy adapter to project
cp platforms/claude-code/CLAUDE.md your-project/

# Or use init script
bash scripts/init-platform.sh claude-code
```

#### Cursor / Windsurf
```bash
# Generate rules file
bash scripts/init-platform.sh cursor
```

#### GitHub Copilot
```bash
# Generate instructions
bash scripts/init-platform.sh copilot
```

#### Aider
```bash
# Generate config
bash scripts/init-platform.sh aider
```

#### Hermes
```bash
# Copy to Hermes skills directory
cp platforms/hermes/SKILL.md ~/.hermes/skills/compound-system/SKILL.md
```

#### Codex
```bash
# Copy to project root
cp platforms/codex/codex.md your-project/
```

## Usage

### After a Task

```bash
# Auto-detect reflection level
scripts/compound.sh --task "implemented auth system" --status "success"

# With error context
scripts/compound.sh --task "fixed API 401" --status "failed" --error "OpenCode Go key endpoint mismatch"
```

### Before a Task

```bash
# Search for similar errors
scripts/search.sh "401 expired key"

# Search by tag
scripts/search.sh "[auth] api"

# Search by module
scripts/search.sh "lark-cli"
```

### Maintenance

```bash
# Check for stale docs (dry run)
scripts/refresh.sh --dry-run

# Archive stale docs
scripts/refresh.sh

# Custom staleness threshold
scripts/refresh.sh --days 60
```

## Cross-Platform Support

### Windows

The system supports Windows through Git Bash, MSYS2, or WSL:

```bash
# Using Git Bash (recommended)
# Scripts work directly with bash

# Using Command Prompt or PowerShell
# Use the wrapper script
scripts\setup.bat
scripts\compound.bat reflect "task" success medium
scripts\compound.bat search "error"
```

### macOS / Linux

```bash
# Standard bash execution
bash scripts/setup.sh
bash scripts/reflect.sh "task" success medium
bash scripts/search.sh "error"
```

### Python Dependency

The system uses Python for LLM API calls. Python 3.6+ is required:

```bash
# Check Python version
python3 --version  # or python --version

# Install PyYAML (optional, for config parsing)
pip install pyyaml
```

## Search Tips

1. **Tag search**: `[tag] keyword` — e.g., `[auth] api key`
2. **Module search**: `module error` — e.g., `lark-cli timeout`
3. **Error code**: Just the code — e.g., `401`, `500`
4. **Check CONCEPTS.md**: Auto-maintained vocabulary for your project
5. **Frontmatter first**: grep searches YAML frontmatter before content

## Contributing

1. Add solutions to `solutions/` directory (use `--tier` flag for working/longterm)
2. Use the templates in `templates/`
3. Run `scripts/refresh.sh` to update CONCEPTS.md
4. Add tests for new scripts

## License

MIT
