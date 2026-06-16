# Plan: Checkpoint 断点恢复（P1）

> **目标**：复杂任务中断后能从断点继续，而不是从头来
>
> **现状**：agent 跑复杂任务（如 code-with-review-hook）如果中断，进度丢失
>
> **借鉴来源**：LangGraph Checkpoint 机制
>
> **⚠️ 依赖**：Task 2 引用了 Plan 1 (Memory Layers) 中定义的 `LONGTERM_DIR`。如果 Plan 1 未完成，将 `CHECKPOINT_DIR` 添加在 `SOLUTIONS_DIR` 之后。

---

## 当前问题

| 问题 | 表现 |
|------|------|
| 中断丢失进度 | subagent 被 /stop 或超时中断，已完成的步骤白费 |
| 重复劳动 | 同一个任务要从头跑一遍 |
| 无状态快照 | 不知道任务执行到哪一步 |

## 设计方案

借鉴 LangGraph 的 checkpoint 思路，但适配 bash 场景：

```
.checkpoints/            # 独立于 solutions/
├── task-001.json        # 每个任务一个 checkpoint
└── task-002.json

checkpoint.json 结构：
{
  "task_id": "唯一标识",
  "phase": "当前阶段",
  "completed_steps": ["step1", "step2"],
  "pending_steps": ["step3"],
  "context": {"key": "value"},
  "created_at": "ISO时间",
  "updated_at": "ISO时间"
}
```

## 文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `scripts/checkpoint.sh` | 新建 | checkpoint 读写核心 |
| `scripts/compound.sh` | 修改 | 添加 checkpoint action |
| `scripts/utils.sh` | 修改 | 添加 CHECKPOINT_DIR 路径 |
| `tests/test_checkpoint.sh` | 新建 | checkpoint 功能测试 |

---

## Task 1: 创建 checkpoint.sh

**目标**：checkpoint 的读/写/清除/列出核心函数

**文件**：`scripts/checkpoint.sh`（新建）

**实现**：

```bash
#!/usr/bin/env bash
set -euo pipefail
# checkpoint.sh — Task checkpoint management
# Usage:
#   checkpoint.sh save <task_id> <phase> <completed_json> <pending_json> [context]
#   checkpoint.sh load <task_id>
#   checkpoint.sh clear <task_id>
#   checkpoint.sh list
#   checkpoint.sh exists <task_id>

source "$(dirname "$0")/utils.sh"

# Standalone fallback if utils.sh doesn't define CHECKPOINT_DIR yet
CHECKPOINT_DIR="${CHECKPOINT_DIR:-${COMPOUND_ROOT}/.checkpoints}"
mkdir -p "$CHECKPOINT_DIR"

action="${1:-help}"

case "$action" in
    save)
        TASK_ID="${2:?Usage: checkpoint.sh save <task_id> <phase> <completed> <pending> [context]}"
        PHASE="${3:-init}"
        COMPLETED="${4:-[]}"
        PENDING="${5:-[]}"
        CONTEXT="${6:-{}}"

        # Validate: no quotes or backslashes in task_id/phase
        if [[ "$TASK_ID" =~ [\"\\] ]] || [[ "$PHASE" =~ [\"\\] ]]; then
            log_error "Invalid characters in task_id or phase (no quotes or backslashes)"
            exit 1
        fi

        FILE="$CHECKPOINT_DIR/${TASK_ID}.json"
        cat > "$FILE" << CP_EOF
{
  "task_id": "$TASK_ID",
  "phase": "$PHASE",
  "completed_steps": $COMPLETED,
  "pending_steps": $PENDING,
  "context": $CONTEXT,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CP_EOF
        log_ok "Checkpoint saved: $TASK_ID (phase: $PHASE)"
        echo "$FILE"
        ;;

    load)
        TASK_ID="${2:?Usage: checkpoint.sh load <task_id>}"
        FILE="$CHECKPOINT_DIR/${TASK_ID}.json"
        if [[ ! -f "$FILE" ]]; then
            log_error "No checkpoint found: $TASK_ID"
            exit 1
        fi
        cat "$FILE"
        ;;

    clear)
        TASK_ID="${2:?Usage: checkpoint.sh clear <task_id>}"
        FILE="$CHECKPOINT_DIR/${TASK_ID}.json"
        if [[ -f "$FILE" ]]; then
            rm "$FILE"
            log_ok "Checkpoint cleared: $TASK_ID"
        else
            log_warn "No checkpoint to clear: $TASK_ID"
        fi
        ;;

    list)
        if [[ ! -d "$CHECKPOINT_DIR" ]] || [[ -z "$(ls -A "$CHECKPOINT_DIR" 2>/dev/null)" ]]; then
            log_info "No active checkpoints"
            exit 0
        fi
        log_info "Active checkpoints:"
        for f in "$CHECKPOINT_DIR"/*.json; do
            [[ -f "$f" ]] || continue
            TASK_ID=$(jq -r '.task_id' "$f")
            PHASE=$(jq -r '.phase' "$f")
            UPDATED=$(jq -r '.updated_at' "$f")
            COMPLETED=$(jq -r '.completed_steps | length' "$f")
            PENDING=$(jq -r '.pending_steps | length' "$f")
            echo "  $TASK_ID | phase=$PHASE | done=$COMPLETED | pending=$PENDING | updated=$UPDATED"
        done
        ;;

    exists)
        TASK_ID="${2:?Usage: checkpoint.sh exists <task_id>}"
        FILE="$CHECKPOINT_DIR/${TASK_ID}.json"
        [[ -f "$FILE" ]] && echo "true" || echo "false"
        ;;

    help|*)
        echo "checkpoint.sh — Task checkpoint management"
        echo ""
        echo "Usage:"
        echo "  checkpoint.sh save <task_id> <phase> <completed_json> <pending_json> [context]"
        echo "  checkpoint.sh load <task_id>"
        echo "  checkpoint.sh clear <task_id>"
        echo "  checkpoint.sh list"
        echo "  checkpoint.sh exists <task_id>"
        ;;
esac
```

**验证**：

```bash
# 保存
bash scripts/checkpoint.sh save "task-001" "research" '["step1"]' '["step2","step3"]'

# 加载
bash scripts/checkpoint.sh load "task-001" | jq .

# 列出
bash scripts/checkpoint.sh list

# 检查存在
bash scripts/checkpoint.sh exists "task-001"
# 期望：true

bash scripts/checkpoint.sh exists "task-999"
# 期望：false

# 清除
bash scripts/checkpoint.sh clear "task-001"
bash scripts/checkpoint.sh exists "task-001"
# 期望：false
```

**验收标准**：
- [ ] save/load/clear/list/exists 五个命令正常工作
- [ ] JSON 格式正确，可用 jq 解析
- [ ] 不存在的 checkpoint 加载时返回错误
- [ ] 非法字符（引号/反斜杠）输入被拒绝

---

## Task 2: 修改 utils.sh — 添加 CHECKPOINT_DIR

**目标**：统一 checkpoint 路径常量

**文件**：`scripts/utils.sh`

**变更**：在文件末尾（`target_dir_for` 函数之后）添加：

```bash
# Checkpoint 目录
CHECKPOINT_DIR="${COMPOUND_ROOT}/.checkpoints"
```

> **注意**：如果 Plan 1 (Memory Layers) 未完成，`LONGTERM_DIR` 不存在。此时将 `CHECKPOINT_DIR` 添加在 `SOLUTIONS_DIR` 定义之后即可。

**验收标准**：
- [ ] `source scripts/utils.sh` 后 `$CHECKPOINT_DIR` 有值

---

## Task 3: 修改 compound.sh — 添加 checkpoint action

**目标**：通过 `compound.sh checkpoint <action>` 统一入口

**文件**：`scripts/compound.sh`

**变更**：在 case 语句中（`refresh)` 之前）添加：

```bash
checkpoint)
    shift
    bash "$(dirname "$0")/checkpoint.sh" "$@"
    ;;
```

**变更**：在 help case 中添加：

```bash
echo "  checkpoint <action> — manage task checkpoints"
echo "    save <id> <phase> <completed> <pending> [context]"
echo "    load <id>"
echo "    list"
echo "    clear <id>"
```

**验证**：

```bash
compound.sh checkpoint save "my-task" "phase1" '["s1"]' '["s2"]'
compound.sh checkpoint load "my-task"
compound.sh checkpoint list
compound.sh checkpoint clear "my-task"
```

**验收标准**：
- [ ] `compound.sh checkpoint list` 能列出检查点
- [ ] 路由到 checkpoint.sh 正确
- [ ] `compound.sh help` 显示 checkpoint 用法

---

## Task 4: 创建测试

**目标**：完整测试 checkpoint 功能

**文件**：`tests/test_checkpoint.sh`（新建）

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/utils.sh"

# Standalone fallback
CHECKPOINT_DIR="${CHECKPOINT_DIR:-${COMPOUND_ROOT}/.checkpoints}"

PASS=0 FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✅ $desc"
        ((PASS++))
    else
        echo "  ❌ $desc (expected='$expected', got='$actual')"
        ((FAIL++))
    fi
}

assert_true() {
    local desc="$1" actual="$2"
    assert_eq "$desc" "true" "$actual"
}

assert_false() {
    local desc="$1" actual="$2"
    assert_eq "$desc" "false" "$actual"
}

echo "=== Checkpoint Tests ==="

# Clean up
rm -rf "$CHECKPOINT_DIR"
mkdir -p "$CHECKPOINT_DIR"

# Test 1: Save and load
TASK_ID="test-$(date +%s)"
bash "$(dirname "$0")/../scripts/checkpoint.sh" save "$TASK_ID" "research" '["s1","s2"]' '["s3"]' '{"key":"value"}'

RESULT=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" load "$TASK_ID")
assert_true "Save creates file" "$([ -f "$CHECKPOINT_DIR/$TASK_ID.json" ] && echo true || echo false)"
assert_eq "Phase saved correctly" "research" "$(echo "$RESULT" | jq -r '.phase')"
assert_eq "Completed steps count" "2" "$(echo "$RESULT" | jq -r '.completed_steps | length')"
assert_eq "Pending steps count" "1" "$(echo "$RESULT" | jq -r '.pending_steps | length')"
assert_eq "Context preserved" "value" "$(echo "$RESULT" | jq -r '.context.key')"

# Test 2: Exists
EXISTS=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" exists "$TASK_ID")
assert_true "Exists returns true" "$EXISTS"

NOT_EXISTS=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" exists "nonexistent-task")
assert_false "Non-existent returns false" "$NOT_EXISTS"

# Test 3: List
LIST=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" list)
assert_true "List includes task" "$(echo "$LIST" | grep -q "$TASK_ID" && echo true || echo false)"

# Test 4: Update (save again with different phase)
bash "$(dirname "$0")/../scripts/checkpoint.sh" save "$TASK_ID" "implementation" '["s1","s2","s3"]' '[]'
UPDATED=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" load "$TASK_ID")
assert_eq "Phase updated" "implementation" "$(echo "$UPDATED" | jq -r '.phase')"
assert_eq "Completed now 3" "3" "$(echo "$UPDATED" | jq -r '.completed_steps | length')"

# Test 5: Clear
bash "$(dirname "$0")/../scripts/checkpoint.sh" clear "$TASK_ID"
CLEAR_EXISTS=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" exists "$TASK_ID")
assert_false "Clear removes file" "$CLEAR_EXISTS"

# Test 6: Load nonexistent fails
LOAD_FAIL=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" load "nonexistent" 2>&1 || true)
assert_true "Load nonexistent shows error" "$(echo "$LOAD_FAIL" | grep -qi "no checkpoint\|not found\|error" && echo true || echo false)"

# Test 7: Invalid characters rejected
INVALID_FAIL=$(bash "$(dirname "$0")/../scripts/checkpoint.sh" save 'bad"id' "phase" '[]' '[]' 2>&1 || true)
assert_true "Quotes in task_id rejected" "$(echo "$INVALID_FAIL" | grep -qi "invalid\|error" && echo true || echo false)"

# Cleanup
rm -rf "$CHECKPOINT_DIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**验收标准**：
- [ ] `bash tests/test_checkpoint.sh` 全部通过
- [ ] 覆盖 save/load/exists/list/clear/update/invalid 七个场景

---

## Task 5: 端到端验证

**目标**：模拟真实使用场景

**步骤**：

```bash
# 场景：调试中断恢复
compound.sh checkpoint save "debug-e2e" "phase2" '["check-logs","find-error"]' '["fix-db","test"]' '{"pr":"123"}'

# 模拟中断后查看
compound.sh checkpoint list
# 期望：debug-e2e | phase=phase2 | done=2 | pending=2

# 恢复
compound.sh checkpoint load "debug-e2e" | jq '.completed_steps'
# 期望：["check-logs","find-error"]

# 完成后清理
compound.sh checkpoint clear "debug-e2e"
compound.sh checkpoint list
# 期望：No active checkpoints
```

**验收标准**：
- [ ] 完整 save → list → load → clear 流程正常
- [ ] 输出格式清晰可读

---

## 执行顺序

```
Task 1 (checkpoint.sh) → Task 2 (utils) → Task 3 (compound.sh) → Task 4 (tests) → Task 5 (e2e)
```

**预计时间**：1-1.5 小时

---

## 使用场景示例

### 场景 1：复杂调试任务中断恢复

```bash
# 1. 开始调试，每完成一步保存 checkpoint
compound.sh checkpoint save "debug-ticketpilot" "phase1" \
  '["check-logs","identify-error"]' \
  '["fix-db","test","deploy"]'

# 2. 继续执行... subagent 被中断

# 3. 下次启动时，检查是否有未完成的 checkpoint
compound.sh checkpoint list
# 输出：debug-ticketpilot | phase=phase1 | done=2 | pending=3 | updated=2026-06-16T...

# 4. 加载 checkpoint，从断点继续
compound.sh checkpoint load "debug-ticketpilot" | jq '.completed_steps'
# ["check-logs","identify-error"]

# 5. 完成后清除
compound.sh checkpoint clear "debug-ticketpilot"
```

### 场景 2：code-with-review-hook 中断恢复

```bash
# review subagent 被中断
compound.sh checkpoint save "review-pr-123" "gate4" \
  '["plan-review","impl","tests"]' \
  '["code-review"]'

# 恢复时跳过已完成步骤
compound.sh checkpoint load "review-pr-123" | jq '.completed_steps'
# 直接从 code-review 开始
```

---

## 风险

| 风险 | 缓解 |
|------|------|
| checkpoint 文件积累 | refresh.sh 可添加清理 7 天前的 checkpoint（可选后续任务） |
| JSON 格式错误 | save 时验证输入字符 + jq 读取时自然报错 |
| 并发 checkpoint 冲突 | task_id 用时间戳+随机数，避免碰撞 |
| 磁盘占用 | checkpoint JSON 很小（<1KB），可忽略 |
| jq 依赖 | 已作为现有依赖使用（write-solution.sh 已用） |
