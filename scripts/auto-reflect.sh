#!/usr/bin/env bash
# Auto-Reflect Hook — 任务完成后自动调用反思
# 用法: auto-reflect.sh <task_description> [status] [severity] [error_messages]
#
# 这个脚本会被 Claude Code 的 hooks 系统调用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOUND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 参数
TASK_DESC="${1:?Usage: auto-reflect.sh <task_description> [status] [severity] [error_messages]}"
STATUS="${2:-success}"
SEVERITY="${3:-none}"
ERROR_MSG="${4:-}"

# 日志函数
log_info() { echo -e "\033[0;34m[AUTO-REFLECT]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[AUTO-REFLECT]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[AUTO-REFLECT]\033[0m $1"; }

# 检查是否需要反思（使用规则门）
check_if_needed() {
    local outcome="$1" severity="$2"

    # 规则 1: 错误 → 必须反思
    if [[ "$outcome" == "failed" || "$outcome" == "error" ]]; then
        return 0
    fi

    # 规则 2: 高严重度 → 必须反思
    if [[ "$severity" == "high" || "$severity" == "blocking" ]]; then
        return 0
    fi

    # 规则 3: 成功 + 无严重问题 → 跳过
    if [[ "$outcome" == "success" && "$severity" == "none" ]]; then
        return 1
    fi

    # 默认: 需要反思
    return 0
}

# 主逻辑
main() {
    log_info "检查是否需要反思: $TASK_DESC"

    # 检查是否需要反思
    if ! check_if_needed "$STATUS" "$SEVERITY"; then
        log_warn "简单任务，跳过反思"
        return 0
    fi

    log_info "开始深度反思..."

    # 调用反思脚本
    RESULT=$(bash "$SCRIPT_DIR/reflect.sh" "$TASK_DESC" "$STATUS" "$SEVERITY" "$ERROR_MSG" 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "反思完成"

        # 解析结果并保存到知识库
        echo "$RESULT" | bash "$SCRIPT_DIR/write-solution.sh" "$TASK_DESC" 2>/dev/null || true

        # 输出结果
        echo "$RESULT"
    else
        log_warn "反思失败: $RESULT"
        return 1
    fi
}

# 执行
main
