#!/usr/bin/env bash
# Compound System - 平台初始化脚本
# 用法: init-platform.sh <platform> [--global]

set -e

COMPOUND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INIT]${NC} $1"; }
log_success() { echo -e "${GREEN}[INIT]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[INIT]${NC} $1"; }
log_error() { echo -e "${RED}[INIT]${NC} $1"; }

# 检测操作系统
detect_os() {
    case "$OSTYPE" in
        msys*|cygwin*|win*) echo "windows" ;;
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

# 检测 Python 命令
detect_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    elif command -v python &>/dev/null; then
        echo "python"
    else
        echo ""
    fi
}

# 生成 Claude Code 适配器
generate_claude_code() {
    local target_dir="${1:-.}"
    local is_global="${2:-false}"

    if [[ "$is_global" == "true" ]]; then
        target_dir="$HOME/.claude"
    fi

    mkdir -p "$target_dir"

    cat > "$target_dir/CLAUDE-compound.md" << 'EOF'
# Compound Engineering System

## 概述

集成 Compound System 用于知识管理和自动反思。

## 使用方法

### 任务后反思

完成任务后，使用以下命令反思：

```bash
# 自动反思（推荐）
bash <COMPOUND_ROOT>/scripts/auto-reflect.sh "任务描述" "success|failed" "none|high"

# 手动深度反思
bash <COMPOUND_ROOT>/scripts/reflect.sh "任务描述" "success" "medium"
```

### 搜索已有方案

```bash
bash <COMPOUND_ROOT>/scripts/search.sh "错误描述"
```

### 任务断点管理

```bash
# 保存断点
bash <COMPOUND_ROOT>/scripts/checkpoint.sh save "task-id" "phase" '["completed"]' '["pending"]'

# 查看断点
bash <COMPOUND_ROOT>/scripts/checkpoint.sh list

# 加载断点
bash <COMPOUND_ROOT>/scripts/checkpoint.sh load "task-id"
```

### 知识库管理

```bash
# 查看状态
bash <COMPOUND_ROOT>/scripts/compound.sh status

# 晋升知识
bash <COMPOUND_ROOT>/scripts/promote.sh solutions/working/discovery.md session

# 维护知识库
bash <COMPOUND_ROOT>/scripts/refresh.sh
```

## 配置

运行配置向导：
```bash
bash <COMPOUND_ROOT>/scripts/setup.sh
```

## 自动反思规则

- 任务失败 → 必须反思
- 高严重度 → 必须反思
- 多次重试 → 必须反思
- 简单成功 → 跳过
EOF

    # 替换 COMPOUND_ROOT
    sed -i.bak "s|<COMPOUND_ROOT>|$COMPOUND_ROOT|g" "$target_dir/CLAUDE-compound.md"
    rm -f "$target_dir/CLAUDE-compound.md.bak"

    log_success "Claude Code adapter generated: $target_dir/CLAUDE-compound.md"
}

# 生成 Cursor/Windsurf 适配器
generate_cursor() {
    local target_dir="${1:-.}"

    mkdir -p "$target_dir/.cursor"

    cat > "$target_dir/.cursor/rules-compound.md" << 'EOF'
# Compound Engineering System Rules

## Post-Task Reflection

After completing any task, run:

```bash
# Auto-reflect
bash <COMPOUND_ROOT>/scripts/auto-reflect.sh "task description" "success|failed"

# Search existing solutions
bash <COMPOUND_ROOT>/scripts/search.sh "error description"
```

## When to Reflect

- Errors or failures → Always reflect
- Multiple retries → Always reflect
- Complex decisions → Always reflect
- Simple config changes → Skip

## Knowledge Base

- `solutions/working/` — Temporary (1 day)
- `solutions/session/` — Short-term (90 days)
- `solutions/longterm/` — Permanent
EOF

    sed -i.bak "s|<COMPOUND_ROOT>|$COMPOUND_ROOT|g" "$target_dir/.cursor/rules-compound.md"
    rm -f "$target_dir/.cursor/rules-compound.md.bak"

    log_success "Cursor adapter generated: $target_dir/.cursor/rules-compound.md"
}

# 生成 GitHub Copilot 适配器
generate_copilot() {
    local target_dir="${1:-.}"

    mkdir -p "$target_dir/.github"

    cat > "$target_dir/.github/copilot-instructions.md" << 'EOF'
# Compound Engineering System

## Post-Task Reflection

After completing any task, use the Compound System for reflection:

```bash
# Reflect on task completion
bash <COMPOUND_ROOT>/scripts/auto-reflect.sh "task description" "success|failed"

# Search for similar issues
bash <COMPOUND_ROOT>/scripts/search.sh "error description"
```

## Knowledge Management

- Search before starting new tasks
- Record errors and solutions
- Use checkpoints for complex tasks
EOF

    sed -i.bak "s|<COMPOUND_ROOT>|$COMPOUND_ROOT|g" "$target_dir/.github/copilot-instructions.md"
    rm -f "$target_dir/.github/copilot-instructions.md.bak"

    log_success "GitHub Copilot adapter generated: $target_dir/.github/copilot-instructions.md"
}

# 生成 Aider 适配器
generate_aider() {
    local target_dir="${1:-.}"

    cat > "$target_dir/.aider.conf.yml" << EOF
# Compound System - Aider Configuration

# Auto-commit after changes
auto-commits: true

# LLM configuration (uses Compound System's config)
# Aider will read from .env file

# Instructions for the AI
read:
  - $COMPOUND_ROOT/CLAUDE.md
EOF

    log_success "Aider adapter generated: $target_dir/.aider.conf.yml"
}

# 生成通用 CONVENTIONS.md
generate_conventions() {
    local target_dir="${1:-.}"

    cat > "$target_dir/CONVENTIONS-compound.md" << 'EOF'
# Compound System Conventions

## After Task Completion

Always run reflection after completing a task:

```bash
# 1. For errors or complex tasks
bash <COMPOUND_ROOT>/scripts/auto-reflect.sh "what you did" "success|failed" "none|high"

# 2. Search before starting
bash <COMPOUND_ROOT>/scripts/search.sh "similar problem"
```

## Knowledge Base Structure

```
solutions/
├── working/     # Temporary (1 day)
├── session/     # Short-term (90 days)
│   ├── bugs/    # Error patterns
│   └── knowledge/  # Best practices
└── longterm/    # Permanent patterns
```

## Checkpoint System

For complex tasks:

```bash
# Save progress
bash <COMPOUND_ROOT>/scripts/checkpoint.sh save "task" "phase" '["done"]' '["todo"]'

# Resume later
bash <COMPOUND_ROOT>/scripts/checkpoint.sh load "task"
```
EOF

    sed -i.bak "s|<COMPOUND_ROOT>|$COMPOUND_ROOT|g" "$target_dir/CONVENTIONS-compound.md"
    rm -f "$target_dir/CONVENTIONS-compound.md.bak"

    log_success "Conventions file generated: $target_dir/CONVENTIONS-compound.md"
}

# 生成 hooks 配置
generate_hooks() {
    local target_dir="${1:-.}"

    # Claude Code hooks
    cat > "$target_dir/hooks-claude-code.json" << EOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $COMPOUND_ROOT/scripts/auto-reflect.sh \\"\\$TOOL_INPUT\\" \\"\\$TOOL_OUTPUT_STATUS\\" 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
EOF

    log_success "Hooks config generated: $target_dir/hooks-claude-code.json"
    log_info "To enable: Copy hooks to your Claude Code settings"
}

# 显示帮助
show_help() {
    echo "Compound System - 平台初始化脚本"
    echo ""
    echo "用法:"
    echo "  init-platform.sh <platform> [target_dir] [--global]"
    echo ""
    echo "平台:"
    echo "  claude-code    Claude Code"
    echo "  cursor         Cursor / Windsurf"
    echo "  copilot        GitHub Copilot"
    echo "  aider          Aider"
    echo "  all            所有平台"
    echo "  conventions    通用约定文件"
    echo "  hooks          生成 hooks 配置"
    echo ""
    echo "选项:"
    echo "  --global       生成到全局目录 (~/.claude, ~/.cursor 等)"
    echo "  --help         显示帮助"
    echo ""
    echo "示例:"
    echo "  # 为当前项目生成 Claude Code 适配器"
    echo "  ./scripts/init-platform.sh claude-code"
    echo ""
    echo "  # 生成到全局目录"
    echo "  ./scripts/init-platform.sh claude-code --global"
    echo ""
    echo "  # 为所有平台生成适配器"
    echo "  ./scripts/init-platform.sh all"
}

# 主函数
main() {
    local platform=""
    local target_dir="."
    local is_global="false"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global)
                is_global="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$platform" ]]; then
                    platform="$1"
                else
                    target_dir="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$platform" ]]; then
        show_help
        exit 1
    fi

    # 执行初始化
    case "$platform" in
        claude-code)
            generate_claude_code "$target_dir" "$is_global"
            ;;
        cursor)
            generate_cursor "$target_dir"
            ;;
        copilot)
            generate_copilot "$target_dir"
            ;;
        aider)
            generate_aider "$target_dir"
            ;;
        conventions)
            generate_conventions "$target_dir"
            ;;
        hooks)
            generate_hooks "$target_dir"
            ;;
        all)
            generate_claude_code "$target_dir" "$is_global"
            generate_cursor "$target_dir"
            generate_copilot "$target_dir"
            generate_aider "$target_dir"
            generate_conventions "$target_dir"
            generate_hooks "$target_dir"
            ;;
        *)
            log_error "未知平台: $platform"
            show_help
            exit 1
            ;;
    esac
}

# 运行
main "$@"
