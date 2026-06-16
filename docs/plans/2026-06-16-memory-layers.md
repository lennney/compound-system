# Plan: Memory 三层分层（P0）

> **目标**：把扁平目录升级为三层记忆结构，让知识有时间维度
>
> **现状**：`solutions/bugs/` `knowledge/` `patterns/` 三个平级目录，90天统一过期
>
> **借鉴来源**：CrewAI Memory 三层 + LangGraph Checkpoint

---

## 当前问题

| 问题 | 表现 |
|------|------|
| 扁平膨胀 | 100+ 文件全在一个目录，grep 逐渐变慢 |
| 无时间维度 | 2天前的 bug 和 89天前的 bug 同级 |
| patterns 无保护 | patterns 是提炼出的永久知识，却和临时 bug 同样 90天过期 |
| 缺少工作记忆 | agent 调试过程中的临时发现无法暂存 |

## 目标架构

```
solutions/
├── working/          # 工作记忆（临时，1天后自动归档）
│   └── .gitkeep
├── session/          # 短期记忆（跨session，90天过期）
│   ├── bugs/
│   ├── knowledge/
│   └── .gitkeep
├── longterm/         # 长期记忆（永久保留）
│   └── patterns/
├── CONCEPTS.md
└── .archive/         # 归档（从 session/working 过期来的）
```

## ⚠️ 迁移注意事项

1. **Cron 安全**：Task 1（目录迁移）和 Task 5（refresh.sh 更新）**必须在同一 session 完成**。如果 cron 在中间运行，旧逻辑会扫描新目录结构，可能误归档 longterm 文件。
2. **test_e2e.sh 兼容**：现有 `tests/test_e2e.sh` 使用旧目录路径，Task 1 后必须更新。
3. **文件极少**：当前只有 1 个文件（test-bug.md），迁移风险极低。

## 变更范围

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `scripts/utils.sh` | 修改 | 添加三层路径函数 |
| `scripts/compound.sh` | 修改 | status 显示三层 |
| `scripts/write-solution.sh` | 修改 | 写入时区分 tier |
| `scripts/search.sh` | 修改 | 搜索范围从三层取 |
| `scripts/refresh.sh` | 修改 | 只过期 session，不动 longterm |
| `scripts/promote.sh` | 新建 | working → session → longterm 晋升 |
| `tests/test_memory_layers.sh` | 新建 | 三层目录结构测试 |
| `tests/test_e2e.sh` | 修改 | 更新为三层路径 |
| `README.md` | 修改 | 更新目录结构说明 |

---

## Task 1: 迁移现有目录结构

**目标**：创建三层目录，把现有文件迁移到 session 层

**⚠️ 前置检查**：

```bash
# 检查 cron 是否正在运行
crontab -l 2>/dev/null | grep compound
# 如果有，先暂停 cron（Task 5 完成后再恢复）
```

**步骤**：

```bash
cd ~/compound-system

# 创建新目录结构
mkdir -p solutions/{working,session/{bugs,knowledge},longterm/patterns}

# 迁移现有文件到 session 层
mv solutions/bugs/*.md solutions/session/bugs/ 2>/dev/null || true
mv solutions/knowledge/*.md solutions/session/knowledge/ 2>/dev/null || true

# 保留 patterns 在 longterm
mv solutions/patterns/*.md solutions/longterm/patterns/ 2>/dev/null || true

# 清理旧空目录
rmdir solutions/bugs solutions/knowledge solutions/patterns 2>/dev/null || true

# 添加 .gitkeep
touch solutions/{working,.archive}/.gitkeep
touch solutions/session/{bugs,knowledge}/.gitkeep
touch solutions/longterm/patterns/.gitkeep
```

**验证**：

```bash
find solutions/ -type f | sort
# 期望：
# solutions/CONCEPTS.md
# solutions/longterm/patterns/.gitkeep
# solutions/session/bugs/2026-06-14-test-bug.md
# solutions/session/bugs/.gitkeep
# solutions/session/knowledge/.gitkeep
# solutions/working/.gitkeep
# solutions/.archive/.gitkeep
```

**验收标准**：
- [ ] `solutions/session/bugs/` 下有现有 bug 文件
- [ ] 旧目录 `solutions/bugs/` 已删除
- [ ] `solutions/longterm/patterns/` 存在

---

## Task 2: 修改 utils.sh — 添加三层路径函数

**目标**：统一管理三层路径的辅助函数

**文件**：`scripts/utils.sh`

**变更**：在 `count_solutions()` 函数之后、文件末尾添加：

```bash
# 三层记忆目录路径
WORKING_DIR="${SOLUTIONS_DIR}/working"
SESSION_DIR="${SOLUTIONS_DIR}/session"
LONGTERM_DIR="${SOLUTIONS_DIR}/longterm"

# 所有搜索目录（从浅到深）
all_search_dirs() {
    echo "$WORKING_DIR $SESSION_DIR/bugs $SESSION_DIR/knowledge $LONGTERM_DIR/patterns"
}

# 按类型获取目标目录
target_dir_for() {
    local track="$1" tier="${2:-session}"
    case "$tier" in
        working)   echo "$WORKING_DIR" ;;
        session)
            case "$track" in
                bug)       echo "$SESSION_DIR/bugs" ;;
                knowledge) echo "$SESSION_DIR/knowledge" ;;
                *)         echo "$SESSION_DIR/bugs" ;;
            esac
            ;;
        longterm)
            case "$track" in
                pattern) echo "$LONGTERM_DIR/patterns" ;;
                *)       echo "$LONGTERM_DIR/patterns" ;;
            esac
            ;;
        *) echo "$SESSION_DIR/bugs" ;;
    esac
}
```

**验证**：

```bash
source scripts/utils.sh
echo "WORKING: $WORKING_DIR"
echo "SESSION: $SESSION_DIR"
echo "LONGTERM: $LONGTERM_DIR"
echo "Bug target: $(target_dir_for bug session)"
echo "Pattern target: $(target_dir_for pattern longterm)"
```

**验收标准**：
- [ ] `source scripts/utils.sh` 无报错
- [ ] `all_search_dirs` 输出 4 个路径
- [ ] `target_dir_for bug session` 返回 `solutions/session/bugs`

---

## Task 3: 修改 write-solution.sh — 支持 tier 参数

**目标**：写入时支持 `--tier working|session|longterm` 参数

**文件**：`scripts/write-solution.sh`

**变更 1**：在解析 JSON 之前（`INPUT="${1:-$(cat)}"` 之前）添加参数解析：

```bash
# 解析 --tier 参数
TIER="session"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier) TIER="$2"; shift 2 ;;
        *) break ;;
    esac
done
```

**变更 2**：替换目录选择逻辑：

```bash
# 旧代码（删除）：
# case "$TRACK" in
#     bug) TARGET_DIR="$SOLUTIONS_DIR/bugs" ;;
#     knowledge) TARGET_DIR="$SOLUTIONS_DIR/knowledge" ;;
#     *) TARGET_DIR="$SOLUTIONS_DIR/bugs" ;;
# esac

# 新代码：
TARGET_DIR=$(target_dir_for "$TRACK" "$TIER")
mkdir -p "$TARGET_DIR"
```

**验证**：

```bash
# 默认写入 session
echo '{"pattern_title":"verify-session","track":"bug","tags":["v"],"error_type":"配置错误","root_cause":"test","solution_summary":"fix"}' | bash scripts/write-solution.sh
ls solutions/session/bugs/*verify-session*

# working 层
echo '{"pattern_title":"verify-working","track":"bug","tags":["v"],"error_type":"配置错误","root_cause":"test","solution_summary":"fix"}' | bash scripts/write-solution.sh --tier working
ls solutions/working/*verify-working*

# 清理
rm solutions/session/bugs/*verify-session* solutions/working/*verify-working*
```

**验收标准**：
- [ ] `--tier working` 写入到 `solutions/working/`
- [ ] `--tier session`（默认）写入到 `solutions/session/bugs/`
- [ ] `--tier longterm` 写入到 `solutions/longterm/patterns/`

---

## Task 4: 修改 search.sh — 搜索三层

**目标**：搜索时遍历 working → session → longterm，结果标注来源层

**文件**：`scripts/search.sh`

**变更 1**：替换搜索路径构建：

```bash
# 旧代码（删除）：
# if [[ -n "$TRACK" ]]; then
#     SEARCH_PATHS=("$SOLUTIONS_DIR/$TRACK")
# else
#     SEARCH_PATHS=("$SOLUTIONS_DIR/bugs" "$SOLUTIONS_DIR/knowledge" "$SOLUTIONS_DIR/patterns")
# fi

# 新代码：搜索三层
if [[ -n "$TRACK" ]]; then
    SEARCH_PATHS=()
    case "$TRACK" in
        bug)       SEARCH_PATHS+=("$WORKING_DIR" "$SESSION_DIR/bugs") ;;
        knowledge) SEARCH_PATHS+=("$WORKING_DIR" "$SESSION_DIR/knowledge") ;;
        pattern)   SEARCH_PATHS+=("$LONGTERM_DIR/patterns") ;;
        all)       SEARCH_PATHS+=("$WORKING_DIR" "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" "$LONGTERM_DIR/patterns") ;;
    esac
else
    SEARCH_PATHS=("$WORKING_DIR" "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" "$LONGTERM_DIR/patterns")
fi
```

**变更 2**：在输出中标注来源层（在 `echo -e "${GREEN}[$count]${NC} $title"` 那行之后）：

```bash
tier_label=""
case "$file" in
    */working/*)     tier_label=" [工作记忆]" ;;
    */session/*)     tier_label=" [短期记忆]" ;;
    */longterm/*)    tier_label=" [长期记忆]" ;;
esac
echo -e "${GREEN}[$count]${NC} $title$tier_label"
```

**验证**：

```bash
# 搜索结果包含层级标注
bash scripts/search.sh "test-bug" | grep -E '\[(工作|短期|长期)记忆\]'

# --track bug 只搜 working + session/bugs
bash scripts/search.sh "test" --track bug | grep -cE 'session/bugs|working'
```

**验收标准**：
- [ ] 搜索结果包含 `[工作记忆]` `[短期记忆]` `[长期记忆]` 标注
- [ ] `--track bug` 只搜 working + session/bugs

---

## Task 5: 修改 refresh.sh — 只过期 session

**目标**：refresh 只对 session 层执行 90 天过期，longterm 永不过期，working 超过 1 天自动归档

**文件**：`scripts/refresh.sh`

**变更 1**：修改 Stage 1 扫描范围，替换 `find` 路径：

```bash
# 旧代码（Stage 1 中的 find）：
# done < <(find "$SOLUTIONS_DIR" -name "*.md" -not -name "CONCEPTS.md" -not -path "*/.archive/*" 2>/dev/null)

# 新代码：只扫描 session 层
done < <(find "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" -name "*.md" -not -name "CONCEPTS.md" 2>/dev/null)
```

**变更 2**：在 Stage 1 之后添加 Stage 1b（working 层归档）：

```bash
# --- Stage 1b: Archive working docs (>1 day) ---
WORKING_ARCHIVE=0
if [[ -d "$WORKING_DIR" ]]; then
    for file in "$WORKING_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        CREATED=$(grep -m1 "^created:" "$file" 2>/dev/null | sed 's/^created: *//' | tr -d '"')
        [[ -z "$CREATED" ]] && continue
        created_epoch=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)
        [[ "$created_epoch" = 0 ]] && continue
        days_old=$(( (NOW - created_epoch) / 86400 ))
        if [[ "$days_old" -ge 1 ]]; then
            echo "  WORKING→ARCHIVE: $(basename "$file") — ${days_old}d old"
            WORKING_ARCHIVE=$((WORKING_ARCHIVE + 1))
            [[ "$DRY_RUN" = 0 ]] && mv "$file" "$SOLUTIONS_DIR/.archive/"
        fi
    done
fi
```

**变更 3**：在 Stage 1 之后添加 Stage 1c（longterm 统计，不归档）：

```bash
# --- Stage 1c: Report longterm (no expiry) ---
LONGTERM_COUNT=0
if [[ -d "$LONGTERM_DIR/patterns" ]]; then
    LONGTERM_COUNT=$(find "$LONGTERM_DIR/patterns" -name "*.md" 2>/dev/null | wc -l)
    [[ "$LONGTERM_COUNT" -gt 0 ]] && echo "  Longterm (permanent): $LONGTERM_COUNT patterns"
fi
```

**变更 4**：更新 CONCEPTS.md 生成，添加三层统计：

```bash
# 旧代码：
# total_solutions=$(find "$SOLUTIONS_DIR" -name "*.md" -not -name "CONCEPTS.md" -not -path "*/.archive/*" 2>/dev/null | wc -l)

# 新代码：
working_count=$(find "$WORKING_DIR" -name "*.md" 2>/dev/null | wc -l)
session_count=$(find "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" -name "*.md" 2>/dev/null | wc -l)
longterm_count=$(find "$LONGTERM_DIR/patterns" -name "*.md" 2>/dev/null | wc -l)
total_solutions=$((working_count + session_count + longterm_count))
```

**验收标准**：
- [ ] working 层超过 1 天的文件被归档
- [ ] session 层超过 90 天的文件被归档
- [ ] longterm 层文件不被归档
- [ ] CONCEPTS.md 包含三层统计

---

## Task 6: 修改 compound.sh — status 显示三层

**目标**：`compound.sh status` 显示三层记忆统计

**文件**：`scripts/compound.sh`

**变更**：替换 status case 中的输出：

```bash
status)
    log_info "Memory Layers:"
    echo "  Working (临时):  $(count_solutions "$WORKING_DIR")"
    echo "  Session (短期):"
    echo "    Bugs:      $(count_solutions "$SESSION_DIR/bugs")"
    echo "    Knowledge: $(count_solutions "$SESSION_DIR/knowledge")"
    echo "  Longterm (长期):"
    echo "    Patterns:  $(count_solutions "$LONGTERM_DIR/patterns")"
    total=$(count_solutions "$WORKING_DIR")
    total=$((total + $(count_solutions "$SESSION_DIR/bugs")))
    total=$((total + $(count_solutions "$SESSION_DIR/knowledge")))
    total=$((total + $(count_solutions "$LONGTERM_DIR/patterns")))
    echo "  ──────────────"
    echo "  Total: $total"
    ;;
```

**验收标准**：
- [ ] `compound.sh status` 输出三层统计
- [ ] Total 等于三层之和

---

## Task 7: 新建 promote.sh — 晋升机制

**目标**：working → session → longterm 的知识晋升流程

**文件**：`scripts/promote.sh`（新建）

```bash
#!/usr/bin/env bash
set -euo pipefail
# promote.sh — 晋升知识层级
# Usage: promote.sh <file> <target_tier>
#   target_tier: session | longterm
#
# Examples:
#   promote.sh solutions/working/foo.md session
#   promote.sh solutions/session/bugs/bar.md longterm

source "$(dirname "$0")/utils.sh"

FILE="${1:?Usage: promote.sh <file> <target_tier>}"
TARGET_TIER="${2:?Usage: promote.sh <file> <target_tier>}"

[[ ! -f "$FILE" ]] && { log_error "File not found: $FILE"; exit 1; }

TITLE=$(yaml_get "$FILE" "title")
TRACK=$(yaml_get "$FILE" "track")
[[ -z "$TRACK" ]] && TRACK="bug"

# 确定目标路径
case "$TARGET_TIER" in
    session)
        DEST_DIR=$(target_dir_for "$TRACK" session)
        ;;
    longterm)
        DEST_DIR=$(target_dir_for "$TRACK" longterm)
        ;;
    *)
        log_error "Invalid target: $TARGET_TIER (use session|longterm)"
        exit 1
        ;;
esac

mkdir -p "$DEST_DIR"
DEST_FILE="$DEST_DIR/$(basename "$FILE")"

if [[ -f "$DEST_FILE" ]]; then
    log_warn "Target already exists: $DEST_FILE"
    log_info "Merging occurrence_count..."
    OLD_COUNT=$(yaml_get "$DEST_FILE" "occurrence_count")
    NEW_COUNT=$((OLD_COUNT + 1))
    sed -i "s/^occurrence_count: .*/occurrence_count: ${NEW_COUNT}/" "$DEST_FILE"
    rm "$FILE"
    log_ok "Merged and removed source"
else
    mv "$FILE" "$DEST_FILE"
    log_ok "Promoted: $FILE → $DEST_FILE"
fi
```

**验收标准**：
- [ ] `promote.sh <file> session` 移动到 session 对应目录
- [ ] `promote.sh <file> longterm` 移动到 longterm/patterns/
- [ ] 目标已存在时合并 occurrence_count
- [ ] 源文件被删除

---

## Task 8: 更新测试

**目标**：更新现有 e2e 测试 + 创建三层结构测试

### Task 8a: 修复 test_e2e.sh

**文件**：`tests/test_e2e.sh`

**变更**：找到 setup 函数中的目录创建，替换为：

```bash
# 旧代码
# mkdir -p "$SOLUTIONS_DIR"/{bugs,knowledge,patterns}

# 新代码
mkdir -p "$SOLUTIONS_DIR"/{working,session/{bugs,knowledge},longterm/patterns}
```

同时更新所有硬编码路径：`$SOLUTIONS_DIR/bugs` → `$SOLUTIONS_DIR/session/bugs`，`$SOLUTIONS_DIR/knowledge` → `$SOLUTIONS_DIR/session/knowledge`

**验收标准**：
- [ ] `bash tests/test_e2e.sh` 全部通过

### Task 8b: 新建 test_memory_layers.sh

**文件**：`tests/test_memory_layers.sh`（新建）

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/utils.sh"

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

echo "=== Memory Layers Tests ==="

# Test 1: 目录结构
assert_eq "WORKING_DIR exists" "true" "$([ -d "$WORKING_DIR" ] && echo true || echo false)"
assert_eq "SESSION_DIR exists" "true" "$([ -d "$SESSION_DIR" ] && echo true || echo false)"
assert_eq "LONGTERM_DIR exists" "true" "$([ -d "$LONGTERM_DIR" ] && echo true || echo false)"
assert_eq "session/bugs exists" "true" "$([ -d "$SESSION_DIR/bugs" ] && echo true || echo false)"
assert_eq "session/knowledge exists" "true" "$([ -d "$SESSION_DIR/knowledge" ] && echo true || echo false)"
assert_eq "longterm/patterns exists" "true" "$([ -d "$LONGTERM_DIR/patterns" ] && echo true || echo false)"

# Test 2: target_dir_for 函数
assert_eq "bug→session" "$SESSION_DIR/bugs" "$(target_dir_for bug session)"
assert_eq "knowledge→session" "$SESSION_DIR/knowledge" "$(target_dir_for knowledge session)"
assert_eq "pattern→longterm" "$LONGTERM_DIR/patterns" "$(target_dir_for pattern longterm)"

# Test 3: all_search_dirs 输出
SEARCH_DIRS=$(all_search_dirs)
assert_eq "search dirs contains working" "true" "$(echo "$SEARCH_DIRS" | grep -q working && echo true || echo false)"
assert_eq "search dirs contains longterm" "true" "$(echo "$SEARCH_DIRS" | grep -q longterm && echo true || echo false)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

**验收标准**：
- [ ] `bash tests/test_memory_layers.sh` 全部通过

---

## Task 9: 更新 README.md

**目标**：更新目录结构说明

**文件**：`README.md`

**变更**：更新目录树，反映三层架构：

```markdown
## Directory Structure

\```
solutions/
├── working/          # 工作记忆（临时，1天后自动归档）
├── session/          # 短期记忆（90天过期）
│   ├── bugs/         # Bug Track
│   └── knowledge/    # Knowledge Track
├── longterm/         # 长期记忆（永久保留）
│   └── patterns/     # 通用模式
├── CONCEPTS.md       # 词汇表
└── .archive/         # 归档
\```

## Memory Tiers

| Tier | 目录 | 过期策略 | 用途 |
|------|------|---------|------|
| Working | `working/` | 1天自动归档 | 任务调试中的临时发现 |
| Session | `session/` | 90天归档 | 跨session的错误和知识 |
| Longterm | `longterm/` | 永不过期 | 提炼出的通用模式 |
```

**验收标准**：
- [ ] README 中目录结构与实际一致
- [ ] 包含三层使用说明

---

## 执行顺序

```
⚠️ Task 1 + Task 5 必须连续执行（cron 安全）

Task 1 (目录迁移) → Task 2 (utils) → Task 3 (write) → Task 4 (search)
                                                              ↓
Task 5 (refresh) ← Task 6 (status) ← Task 7 (promote) ←────┘
                         ↓
                    Task 8a (修复 e2e)
                         ↓
                    Task 8b (新测试)
                         ↓
                    Task 9 (README)
```

**预计时间**：2-3 小时（含测试）

---

## 风险

| 风险 | 缓解 |
|------|------|
| Cron 在迁移期间运行 | Task 1 前检查并暂停 cron，Task 5 后恢复 |
| test_e2e.sh 路径失效 | Task 8a 专门修复 |
| fact_store 引用 compound-system | 无直接引用，安全 |
| search.sh grep 路径变长 | 性能影响微乎其微（<20 个文件） |
