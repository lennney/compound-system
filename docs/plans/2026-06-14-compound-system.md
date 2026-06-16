# Compound System — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.
>
> **Goal:** Build a cross-platform post-task reflection system that captures error patterns and knowledge as structured Markdown files, with three-tier cost filtering and smart retrieval.
>
> **Architecture:** Pure file-system based (Markdown + YAML frontmatter). Three-tier cost filtering (Rule Gate → Quick Reflect → Deep Reflect). Dual-track capture (Bug + Knowledge). Grep-based pre-filtering for retrieval. Platform adapters for Hermes/Claude Code/Codex.
>
> **Tech Stack:** bash, grep, sed, jq, YAML (Python optional for LLM calls). No database, no web server.
>
> **参考:** Compound Engineering Plugin (github.com/EveryInc/compound-engineering-plugin)

---

## 目录结构

```
compound-system/
├── solutions/                          # 存储位置（可 symlink 到项目）
│   ├── bugs/                           # Bug Track
│   ├── knowledge/                      # Knowledge Track
│   ├── patterns/                       # 通用模式（从 bugs/knowledge 提炼）
│   └── CONCEPTS.md                     # 项目词汇表
├── scripts/
│   ├── compound.sh                     # 主入口：任务后反思
│   ├── reflect.sh                      # Level 1: Quick Reflect
│   ├── deep-reflect.sh                 # Level 2: Deep Reflect
│   ├── search.sh                       # 检索入口
│   ├── refresh.sh                      # 生命周期维护
│   └── utils.sh                        # 共享函数
├── templates/
│   ├── bug.md                          # Bug Track 模板
│   ├── knowledge.md                    # Knowledge Track 模板
│   └── pattern.md                      # Pattern 模板
├── platforms/
│   ├── hermes/                         # Hermes Skill
│   │   └── SKILL.md
│   ├── claude-code/                    # Claude Code Plugin
│   │   └── CLAUDE.md
│   ├── codex/                          # Codex Plugin
│   │   └── codex.md
│   └── cursor/                         # Cursor Rules
│       └── .cursorrules
├── docs/
│   ├── requirements/
│   │   └── 2026-06-14-compound-system.md
│   └── plans/
│       └── 2026-06-14-compound-system.md  # 本文件
├── tests/
│   ├── test_rule_gate.sh
│   ├── test_search.sh
│   └── test_refresh.sh
└── README.md
```

---

## Phase 1: Core Infrastructure（核心基础设施）

### Task 1: Create project structure and shared utilities

**Objective:** Set up directory structure and shared bash functions.

**Files:**
- Create: `scripts/utils.sh`
- Create: `solutions/bugs/.gitkeep`
- Create: `solutions/knowledge/.gitkeep`
- Create: `solutions/patterns/.gitkeep`
- Create: `solutions/CONCEPTS.md`

**Step 1: Create directories**

```bash
cd ~/compound-system
mkdir -p solutions/{bugs,knowledge,patterns}
mkdir -p scripts templates platforms/{hermes,claude-code,codex,cursor} tests docs
touch solutions/bugs/.gitkeep solutions/knowledge/.gitkeep solutions/patterns/.gitkeep
```

**Step 2: Write shared utilities**

```bash
cat > scripts/utils.sh << 'UTILS_EOF'
#!/usr/bin/env bash
# Compound System — Shared Utilities

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
COMPOUND_ROOT="${COMPOUND_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SOLUTIONS_DIR="${COMPOUND_ROOT}/solutions"

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Generate filename from title
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Get current date prefix
date_prefix() {
    date +%Y-%m-%d
}

# Extract YAML frontmatter value
yaml_get() {
    local file="$1" key="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | head -1 | sed "s/^${key}: *//"
}

# Count solutions in a directory
count_solutions() {
    local dir="$1"
    find "$dir" -name "*.md" -not -name "CONCEPTS.md" -not -name ".gitkeep" 2>/dev/null | wc -l
}
UTILS_EOF
chmod +x scripts/utils.sh
```

**Step 3: Create CONCEPTS.md**

```bash
cat > solutions/CONCEPTS.md << 'CONCEPTS_EOF'
---
title: "Project Vocabulary"
last_updated: "$(date +%Y-%m-%d)"
---

# Concepts

> Auto-maintained vocabulary. Terms are added when they appear in solutions.

## Terms

<!-- Terms will be auto-added here -->
CONCEPTS_EOF
```

**Acceptance Criteria:**
1. `scripts/utils.sh` 可被 `source` 加载，无报错
2. `solutions/` 下有 `bugs/`, `knowledge/`, `patterns/` 三个目录
3. `solutions/CONCEPTS.md` 存在且格式正确
4. `bash -n scripts/utils.sh` 语法检查通过

---

### Task 2: Create solution templates

**Objective:** Define Markdown + YAML frontmatter templates for Bug, Knowledge, and Pattern tracks.

**Files:**
- Create: `templates/bug.md`
- Create: `templates/knowledge.md`
- Create: `templates/pattern.md`

**Step 1: Bug Track template**

```bash
cat > templates/bug.md << 'BUG_EOF'
---
title: "{{TITLE}}"
module: "{{MODULE}}"
tags: [{{TAGS}}]
problem_type: "{{PROBLEM_TYPE}}"
severity: "{{SEVERITY}}"
root_cause: "{{ROOT_CAUSE}}"
created: "{{DATE}}"
last_updated: "{{DATE}}"
occurrence_count: 1
status: active
---

# {{TITLE}}

## 问题现象

{{SYMPTOMS}}

## 排查过程

{{INVESTIGATION_STEPS}}

## 根本原因

{{ROOT_CAUSE_DETAIL}}

## 解决方案

{{SOLUTION}}

## 决策记录

{{DECISIONS}}

## 预防措施

{{PREVENTION}}

## 验证方法

{{VERIFICATION}}
BUG_EOF
```

**Step 2: Knowledge Track template**

```bash
cat > templates/knowledge.md << 'KNOW_EOF'
---
title: "{{TITLE}}"
module: "{{MODULE}}"
tags: [{{TAGS}}]
knowledge_type: "{{KNOWLEDGE_TYPE}}"
created: "{{DATE}}"
last_updated: "{{DATE}}"
confidence: 0.8
status: active
---

# {{TITLE}}

## 上下文

{{CONTEXT}}

## 指导原则

{{GUIDANCE}}

## 为什么重要

{{WHY_IT_MATTERS}}

## 适用场景

{{WHEN_TO_APPLY}}

## 示例

{{EXAMPLES}}
KNOW_EOF
```

**Step 3: Pattern template**

```bash
cat > templates/pattern.md << 'PAT_EOF'
---
title: "{{TITLE}}"
tags: [{{TAGS}}]
pattern_type: "{{PATTERN_TYPE}}"
source_count: 0
created: "{{DATE}}"
last_updated: "{{DATE}}"
status: active
---

# {{TITLE}}

## 模式描述

{{DESCRIPTION}}

## 适用场景

{{WHEN_TO_APPLY}}

## 实现步骤

{{STEPS}}

## 注意事项

{{CAVEATS}}

## 来源

{{SOURCES}}
PAT_EOF
```

**Acceptance Criteria:**
1. 三个模板文件存在且格式正确
2. YAML frontmatter 包含所有必要字段
3. 模板变量使用 `{{VAR}}` 格式
4. `bash -n` 对所有模板无语法报错（模板本身不是脚本，但检查无意外内容）

---

### Task 3: Implement Rule Gate (Level 0)

**Objective:** Pure-rule filtering to decide if reflection is needed. Zero LLM cost.

**Files:**
- Create: `scripts/compound.sh` (main entry)
- Create: `tests/test_rule_gate.sh`

**Step 1: Write failing test**

```bash
cat > tests/test_rule_gate.sh << 'TEST_EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/utils.sh"
source "$(dirname "$0")/../scripts/compound.sh"

PASS=0 FAIL=0

assert_reflect() {
    local desc="$1" expect="$2" result="$3"
    if [[ "$result" == "$expect" ]]; then
        echo "  ✅ $desc"
        ((PASS++))
    else
        echo "  ❌ $desc (expected=$expect, got=$result)"
        ((FAIL++))
    fi
}

echo "=== Rule Gate Tests ==="

# Test 1: Simple success, no errors → skip
result=$(should_reflect "success" "none" 0 0 0 "")
assert_reflect "Simple success → skip" "skip" "$result"

# Test 2: Error recovered → reflect
result=$(should_reflect "error_recovered" "medium" 0 0 0 "")
assert_reflect "Error recovered → reflect" "reflect" "$result"

# Test 3: Error unresolved → reflect
result=$(should_reflect "error_unresolved" "high" 0 0 0 "")
assert_reflect "Error unresolved → reflect" "reflect" "$result"

# Test 4: Long debug (>5min) → reflect
result=$(should_reflect "success" "none" 301 0 0 "")
assert_reflect "Long debug → reflect" "reflect" "$result"

# Test 5: High retry (>=3) → reflect
result=$(should_reflect "success" "none" 0 3 0 "")
assert_reflect "High retry → reflect" "reflect" "$result"

# Test 6: High severity → reflect
result=$(should_reflect "success" "high" 0 0 0 "")
assert_reflect "High severity → reflect" "reflect" "$result"

# Test 7: Modified important file → reflect
result=$(should_reflect "success" "none" 0 0 0 "MEMORY.md")
assert_reflect "Modified MEMORY.md → reflect" "reflect" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
TEST_EOF
chmod +x tests/test_rule_gate.sh
```

**Step 2: Run test to verify failure**

```bash
bash tests/test_rule_gate.sh
# Expected: FAIL — compound.sh not found or should_reflect not defined
```

**Step 3: Implement Rule Gate**

```bash
cat > scripts/compound.sh << 'COMPOUND_EOF'
#!/usr/bin/env bash
# Compound System — Main Entry Point
# Usage: compound.sh <action> [args]
#
# Actions:
#   reflect <outcome> <severity> <duration> <retries> <files_modified>
#   search <query>
#   refresh
#   status

source "$(dirname "$0")/utils.sh"

# Level 0: Rule Gate — decide if reflection is needed
# Args: outcome severity duration retries files_modified
should_reflect() {
    local outcome="$1" severity="$2" duration="$3" retries="$4" files_modified="$5"

    # Rule 1: Success + no severity + no important files → skip
    if [[ "$outcome" == "success" && "$severity" == "none" ]]; then
        local important_files="MEMORY.md|SKILL.md|config.yaml|AGENTS.md|CLAUDE.md"
        if ! echo "$files_modified" | grep -qE "$important_files"; then
            echo "skip"
            return
        fi
    fi

    # Rule 2: Error recovered → reflect
    if [[ "$outcome" == "error_recovered" ]]; then
        echo "reflect"
        return
    fi

    # Rule 3: Error unresolved → reflect
    if [[ "$outcome" == "error_unresolved" ]]; then
        echo "reflect"
        return
    fi

    # Rule 4: Long debug (>5 min) → reflect
    if [[ "$duration" -gt 300 ]]; then
        echo "reflect"
        return
    fi

    # Rule 5: High retry (>=3) → reflect
    if [[ "$retries" -ge 3 ]]; then
        echo "reflect"
        return
    fi

    # Rule 6: High severity → reflect
    if [[ "$severity" == "high" || "$severity" == "blocking" ]]; then
        echo "reflect"
        return
    fi

    # Default: skip
    echo "skip"
}

# Main entry
case "${1:-help}" in
    reflect)
        outcome="${2:-success}"
        severity="${3:-none}"
        duration="${4:-0}"
        retries="${5:-0}"
        files="${6:-}"
        result=$(should_reflect "$outcome" "$severity" "$duration" "$retries" "$files")
        echo "$result"
        ;;
    search)
        shift
        bash "$(dirname "$0")/search.sh" "$@"
        ;;
    refresh)
        bash "$(dirname "$0")/refresh.sh"
        ;;
    status)
        log_info "Solutions:"
        echo "  Bugs:      $(count_solutions "$SOLUTIONS_DIR/bugs")"
        echo "  Knowledge: $(count_solutions "$SOLUTIONS_DIR/knowledge")"
        echo "  Patterns:  $(count_solutions "$SOLUTIONS_DIR/patterns")"
        ;;
    help|*)
        echo "Compound System — Post-Task Reflection"
        echo ""
        echo "Usage: compound.sh <action> [args]"
        echo ""
        echo "Actions:"
        echo "  reflect <outcome> <severity> <duration> <retries> <files>"
        echo "  search <query>"
        echo "  refresh"
        echo "  status"
        ;;
esac
COMPOUND_EOF
chmod +x scripts/compound.sh
```

**Step 4: Run test to verify pass**

```bash
bash tests/test_rule_gate.sh
# Expected: 7 passed, 0 failed
```

**Step 5: Commit**

```bash
git add scripts/ tests/ templates/ solutions/
git commit -m "feat: core infrastructure — utils, templates, rule gate"
```

**Acceptance Criteria:**
1. `bash tests/test_rule_gate.sh` 输出 7 passed, 0 failed
2. `compound.sh reflect success none 0 0 ""` 输出 `skip`
3. `compound.sh reflect error_recovered medium 0 0 ""` 输出 `reflect`
4. `compound.sh status` 显示 0 bugs, 0 knowledge, 0 patterns

---

### Task 4: Implement Quick Reflect (Level 1)

**Objective:** Lightweight LLM call (~500 tokens) to generate structured summary.

**Files:**
- Create: `scripts/reflect.sh`
- Modify: `scripts/compound.sh` (add reflect action wiring)

**Step 1: Write reflect.sh**

```bash
cat > scripts/reflect.sh << 'REFLECT_EOF'
#!/usr/bin/env bash
# Level 1: Quick Reflect — generate structured summary
# Usage: reflect.sh <task_description> <outcome> <severity> <error_messages>
#
# Requires: LLM_API_KEY env var (supports OpenAI-compatible APIs)
# Optional: LLM_ENDPOINT (default: api.deepseek.com), LLM_MODEL (default: deepseek-v4-flash)

source "$(dirname "$0")/utils.sh"

TASK_DESC="${1:?Usage: reflect.sh <task_description> <outcome> <severity> <error_messages>}"
OUTCOME="${2:-success}"
SEVERITY="${3:-none}"
ERROR_MSG="${4:-}"

# LLM config
LLM_ENDPOINT="${LLM_ENDPOINT:-https://api.deepseek.com/v1}"
LLM_MODEL="${LLM_MODEL:-deepseek-v4-flash}"
LLM_API_KEY="${LLM_API_KEY:?LLM_API_KEY not set}"

PROMPT="你是一个错误模式提取器。分析以下任务执行记录，提取关键信息。

## 任务信息
- 描述: ${TASK_DESC}
- 结果: ${OUTCOME}
- 严重程度: ${SEVERITY}

## 错误信息
${ERROR_MSG:-无}

## 输出要求（JSON）
{
  \"pattern_title\": \"简短标题（<20字）\",
  \"track\": \"bug|knowledge\",
  \"error_type\": \"API错误|配置错误|网络错误|工具错误|代码质量|环境问题|无错误\",
  \"root_cause\": \"根本原因（一句话）\",
  \"solution_summary\": \"解决方案摘要（3步以内）\",
  \"tags\": [\"精确标签1\", \"精确标签2\", \"精确标签3\"],
  \"reusable_pattern\": true,
  \"confidence\": 0.8
}

只输出 JSON，不要其他文字。"

# Call LLM
RESPONSE=$(curl -s "${LLM_ENDPOINT}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${LLM_API_KEY}" \
    -d "$(jq -n \
        --arg model "$LLM_MODEL" \
        --arg prompt "$PROMPT" \
        '{
            model: $model,
            messages: [{role: "user", content: $prompt}],
            max_tokens: 500,
            temperature: 0.3
        }')")

# Extract content
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [[ -z "$CONTENT" ]]; then
    log_error "LLM call failed: $(echo "$RESPONSE" | jq -r '.error.message // "unknown error"')"
    exit 1
fi

# Parse JSON (handle markdown code blocks)
CONTENT=$(echo "$CONTENT" | sed 's/^```json//;s/^```//;s/```$//')

echo "$CONTENT"
REFLECT_EOF
chmod +x scripts/reflect.sh
```

**Step 2: Wire into compound.sh**

Add to `compound.sh`'s case statement:

```bash
    reflect)
        if [[ "${2:-}" == "" ]]; then
            # Interactive mode: read from stdin
            log_info "Reading task context from stdin..."
            CONTEXT=$(cat)
            OUTCOME=$(echo "$CONTEXT" | sed -n 's/.*"outcome"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || echo "success")
            SEVERITY=$(echo "$CONTEXT" | sed -n 's/.*"severity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || echo "none")
            ERROR=$(echo "$CONTEXT" | sed -n 's/.*"error_messages"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || echo "")
            bash "$(dirname "$0")/reflect.sh" "$CONTEXT" "$OUTCOME" "$SEVERITY" "$ERROR"
        else
            bash "$(dirname "$0")/reflect.sh" "$@"
        fi
        ;;
```

**Step 3: Test with mock (no LLM)**

```bash
# Create a test that mocks the LLM call
LLM_API_KEY="test-key" bash -c '
source scripts/utils.sh
source scripts/compound.sh

# Mock curl to return test JSON
curl() {
    echo '{"choices":[{"message":{"content":"{\"pattern_title\":\"test\",\"track\":\"bug\",\"error_type\":\"配置错误\",\"root_cause\":\"test root cause\",\"solution_summary\":\"test solution\",\"tags\":[\"test\",\"mock\"],\"reusable_pattern\":true,\"confidence\":0.8}"}}]}'
}
export -f curl

result=$(bash scripts/reflect.sh "test task" "error_recovered" "medium" "test error")
echo "$result" | jq .
'
```

**Acceptance Criteria:**
1. `reflect.sh` 能解析输入参数并构造 prompt
2. Mock 测试能返回结构化 JSON
3. `compound.sh reflect` 能正确路由到 reflect.sh
4. 输出的 JSON 包含所有必要字段

---

### Task 5: Implement search with grep pre-filter

**Objective:** Zero-cost grep pre-filtering on YAML frontmatter, then fallback to content search.

**Files:**
- Create: `scripts/search.sh`
- Create: `tests/test_search.sh`

**Step 1: Write search.sh**

```bash
cat > scripts/search.sh << 'SEARCH_EOF'
#!/usr/bin/env bash
# Compound System — Search
# Usage: search.sh <query> [--track bug|knowledge|pattern] [--limit N]
#
# Strategy:
#   Layer 1: Grep frontmatter (tags, title, problem_type) — zero cost
#   Layer 2: Grep content — zero cost
#   Layer 3: Fuzzy match — zero cost

source "$(dirname "$0")/utils.sh"

QUERY="${1:?Usage: search.sh <query>}"
TRACK=""
LIMIT=5

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --track) TRACK="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Build search paths
if [[ -n "$TRACK" ]]; then
    SEARCH_PATHS=("$SOLUTIONS_DIR/$TRACK")
else
    SEARCH_PATHS=("$SOLUTIONS_DIR/bugs" "$SOLUTIONS_DIR/knowledge" "$SOLUTIONS_DIR/patterns")
fi

RESULTS=()

# Layer 1: Grep frontmatter (tags, title, problem_type)
for dir in "${SEARCH_PATHS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
        # Check if query matches frontmatter
        if sed -n '/^---$/,/^---$/p' "$file" | grep -qi "$QUERY"; then
            RESULTS+=("$file")
        fi
    done < <(find "$dir" -name "*.md" -not -name "CONCEPTS.md" 2>/dev/null)
done

# Layer 2: Grep content (if not enough results)
if [[ ${#RESULTS[@]} -lt $LIMIT ]]; then
    for dir in "${SEARCH_PATHS[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r file; do
            if grep -qi "$QUERY" "$file" 2>/dev/null; then
                # Avoid duplicates
                found=false
                for r in "${RESULTS[@]}"; do
                    [[ "$r" == "$file" ]] && found=true && break
                done
                $found || RESULTS+=("$file")
            fi
        done < <(find "$dir" -name "*.md" -not -name "CONCEPTS.md" 2>/dev/null)
    done
fi

# Output results
if [[ ${#RESULTS[@]} -eq 0 ]]; then
    log_warn "No solutions found for: $QUERY"
    exit 0
fi

log_info "Found ${#RESULTS[@]} solution(s) for: $QUERY"
echo ""

count=0
for file in "${RESULTS[@]}"; do
    [[ $count -ge $LIMIT ]] && break
    ((count++))

    title=$(yaml_get "$file" "title")
    severity=$(yaml_get "$file" "severity")
    tags=$(yaml_get "$file" "tags")
    created=$(yaml_get "$file" "created")

    echo -e "${GREEN}[$count]${NC} $title"
    echo "    File: ${file#$COMPOUND_ROOT/}"
    [[ -n "$severity" ]] && echo "    Severity: $severity"
    [[ -n "$created" ]] && echo "    Created: $created"
    echo "    Tags: $tags"
    echo ""
done
SEARCH_EOF
chmod +x scripts/search.sh
```

**Step 2: Write test**

```bash
cat > tests/test_search.sh << 'TEST_EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/utils.sh"

PASS=0 FAIL=0

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        echo "  ✅ $desc"
        ((PASS++))
    else
        echo "  ❌ $desc (expected '$expected' in output)"
        ((FAIL++))
    fi
}

echo "=== Search Tests ==="

# Create test data
mkdir -p /tmp/compound-test/solutions/{bugs,knowledge}
cat > /tmp/compound-test/solutions/bugs/test-401.md << 'EOF'
---
title: "API 401 endpoint mismatch"
tags: [401, expired-key, wrong-endpoint]
problem_type: build_error
severity: high
---
# Test
EOF

COMPOUND_ROOT=/tmp/compound-test bash "$(dirname "$0")/../scripts/search.sh" "401" --limit 5 > /tmp/search_result.txt 2>&1

result=$(cat /tmp/search_result.txt)
assert_contains "Finds 401 error" "API 401 endpoint mismatch" "$result"
assert_contains "Shows severity" "high" "$result"

# Test: no results
COMPOUND_ROOT=/tmp/compound-test bash "$(dirname "$0")/../scripts/search.sh" "nonexistent" --limit 5 > /tmp/search_result2.txt 2>&1
result2=$(cat /tmp/search_result2.txt)
assert_contains "Shows warning for no results" "No solutions found" "$result2"

# Cleanup
rm -rf /tmp/compound-test

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
TEST_EOF
chmod +x tests/test_search.sh
```

**Step 3: Run tests**

```bash
bash tests/test_search.sh
# Expected: 3 passed, 0 failed
```

**Acceptance Criteria:**
1. `search.sh "401"` 能找到包含 "401" 的解决方案
2. `search.sh "401" --track bugs` 只搜索 bugs 目录
3. 前 5 条结果按相关性排序
4. 无结果时显示警告
5. `bash tests/test_search.sh` 通过

---

### Task 6: Implement solution writer

**Objective:** Write reflection results to `solutions/` directory with dedup check.

**Files:**
- Create: `scripts/write-solution.sh`
- Modify: `scripts/compound.sh` (wire write-solution)

**Step 1: Write solution writer**

```bash
cat > scripts/write-solution.sh << 'WRITE_EOF'
#!/usr/bin/env bash
# Compound System — Write Solution
# Usage: write-solution.sh <json_input>
#
# Reads JSON from stdin or argument, writes to solutions/ directory.
# Checks for duplicates before writing.

source "$(dirname "$0")/utils.sh"

INPUT="${1:-$(cat)}"

# Parse JSON
TITLE=$(echo "$INPUT" | jq -r '.pattern_title // "Untitled"')
TRACK=$(echo "$INPUT" | jq -r '.track // "bug"')
ERROR_TYPE=$(echo "$INPUT" | jq -r '.error_type // "unknown"')
ROOT_CAUSE=$(echo "$INPUT" | jq -r '.root_cause // ""')
SOLUTION=$(echo "$INPUT" | jq -r '.solution_summary // ""')
TAGS=$(echo "$INPUT" | jq -r '.tags // [] | join(", ")')
SEVERITY=$(echo "$INPUT" | jq -r '.severity // "medium"')
ERROR_MSG=$(echo "$INPUT" | jq -r '.error_messages // ""')
REUSABLE=$(echo "$INPUT" | jq -r '.reusable_pattern // false')
CONFIDENCE=$(echo "$INPUT" | jq -r '.confidence // 0.5')

# Determine target directory
case "$TRACK" in
    bug) TARGET_DIR="$SOLUTIONS_DIR/bugs" ;;
    knowledge) TARGET_DIR="$SOLUTIONS_DIR/knowledge" ;;
    *) TARGET_DIR="$SOLUTIONS_DIR/bugs" ;;
esac

# Generate filename
SLUG=$(slugify "$TITLE")
FILENAME="$(date_prefix)-${SLUG}.md"
FILEPATH="$TARGET_DIR/$FILENAME"

# Check for duplicates (grep frontmatter)
EXISTING=""
for f in "$TARGET_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    EXISTING_TITLE=$(yaml_get "$f" "title")
    if [[ "$EXISTING_TITLE" == "$TITLE" ]]; then
        EXISTING="$f"
        break
    fi
done

if [[ -n "$EXISTING" ]]; then
    log_warn "Duplicate found: ${EXISTING#$COMPOUND_ROOT/}"
    log_info "Updating occurrence count..."

    # Increment occurrence_count
    OLD_COUNT=$(yaml_get "$EXISTING" "occurrence_count")
    NEW_COUNT=$((OLD_COUNT + 1))

    # Update file
    sed -i "s/^occurrence_count: .*/occurrence_count: ${NEW_COUNT}/" "$EXISTING"
    sed -i "s/^last_updated: .*/last_updated: $(date +%Y-%m-%d)/" "$EXISTING"

    log_ok "Updated: ${EXISTING#$COMPOUND_ROOT/} (count: $NEW_COUNT)"
    echo "$EXISTING"
    exit 0
fi

# Write new file
cat > "$FILEPATH" << SOLUTION_EOF
---
title: "${TITLE}"
module: ""
tags: [${TAGS}]
problem_type: "${ERROR_TYPE}"
severity: "${SEVERITY:-medium}"
root_cause: "${ROOT_CAUSE}"
created: "$(date +%Y-%m-%d)"
last_updated: "$(date +%Y-%m-%d)"
occurrence_count: 1
status: active
---

# ${TITLE}

## 问题现象

${ERROR_MSG:-待补充}

## 根本原因

${ROOT_CAUSE}

## 解决方案

${SOLUTION}

## 验证方法

待补充
SOLUTION_EOF

log_ok "Created: ${FILEPATH#$COMPOUND_ROOT/}"
echo "$FILEPATH"
WRITE_EOF
chmod +x scripts/write-solution.sh
```

**Step 2: Wire into compound.sh**

Add after the `reflect` case:

```bash
    write)
        bash "$(dirname "$0")/write-solution.sh" "${2:-$(cat)}"
        ;;
```

**Step 3: Test dedup**

```bash
# Create test data
mkdir -p /tmp/compound-test/solutions/bugs
echo '{"pattern_title":"Test Bug","track":"bug","error_type":"配置错误","root_cause":"test","solution_summary":"fix it","tags":["test"],"reusable_pattern":true,"confidence":0.8}' | \
    COMPOUND_ROOT=/tmp/compound-test bash scripts/write-solution.sh

# Run again — should update, not create
echo '{"pattern_title":"Test Bug","track":"bug","error_type":"配置错误","root_cause":"test","solution_summary":"fix it","tags":["test"],"reusable_pattern":true,"confidence":0.8}' | \
    COMPOUND_ROOT=/tmp/compound-test bash scripts/write-solution.sh

# Check occurrence count
cat /tmp/compound-test/solutions/bugs/*test-bug*.md | grep occurrence_count
# Expected: occurrence_count: 2

rm -rf /tmp/compound-test
```

**Acceptance Criteria:**
1. 首次写入创建新文件
2. 重复标题不创建新文件，而是更新 occurrence_count
3. 文件名格式为 `YYYY-MM-DD-slug.md`
4. YAML frontmatter 包含所有必要字段
5. 去重测试通过（count 从 1 变为 2）

---

## Phase 2: Lifecycle Management（生命周期管理）

### Task 7: Implement refresh (staleness detection)

**Objective:** Scan all solutions, detect stale ones, suggest consolidation.

**Files:**
- Create: `scripts/refresh.sh`
- Create: `tests/test_refresh.sh`

**Step 1: Write refresh.sh**

```bash
cat > scripts/refresh.sh << 'REFRESH_EOF'
#!/usr/bin/env bash
# Compound System — Refresh
# Scans all solutions, detects stale docs, suggests consolidation.
# Usage: refresh.sh [--auto-fix]

source "$(dirname "$0")/utils.sh"

AUTO_FIX="${1:-}"

STALE_THRESHOLD_DAYS=90
TOTAL=0
STALE=0
CONSOLIDATABLE=0

log_info "Scanning solutions..."

for dir in "$SOLUTIONS_DIR/bugs" "$SOLUTIONS_DIR/knowledge" "$SOLUTIONS_DIR/patterns"; do
    [[ -d "$dir" ]] || continue

    for file in "$dir"/*.md; do
        [[ -f "$file" ]] || continue
        [[ "$(basename "$file")" == "CONCEPTS.md" ]] && continue

        ((TOTAL++))
        TITLE=$(yaml_get "$file" "title")
        CREATED=$(yaml_get "$file" "created")
        LAST_UPDATED=$(yaml_get "$file" "last_updated")
        STATUS=$(yaml_get "$file" "status")
        COUNT=$(yaml_get "$file" "occurrence_count")

        # Check staleness
        if [[ -n "$LAST_UPDATED" ]]; then
            LAST_EPOCH=$(date -d "$LAST_UPDATED" +%s 2>/dev/null || echo "0")
            NOW_EPOCH=$(date +%s)
            DAYS_OLD=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))

            if [[ $DAYS_OLD -gt $STALE_THRESHOLD_DAYS ]]; then
                ((STALE++))
                log_warn "STALE ($DAYS_OLD days): $TITLE"
                if [[ "$AUTO_FIX" == "--auto-fix" ]]; then
                    sed -i "s/^status: .*/status: stale/" "$file"
                    log_info "  Marked as stale"
                fi
            fi
        fi

        # Check for consolidation opportunities (same tags)
        TAGS=$(yaml_get "$file" "tags")
        # Simple check: count files with overlapping tags
        MATCHES=$(grep -rl "$TAGS" "$SOLUTIONS_DIR"/*.md 2>/dev/null | wc -l)
        if [[ $MATCHES -gt 2 ]]; then
            ((CONSOLIDATABLE++))
            log_info "CONSOLIDATABLE ($MATCHES matches): $TITLE"
        fi
    done
done

echo ""
log_info "Summary:"
echo "  Total solutions: $TOTAL"
echo "  Stale (>${STALE_THRESHOLD_DAYS} days): $STALE"
echo "  Consolidatable: $CONSOLIDATABLE"
REFRESH_EOF
chmod +x scripts/refresh.sh
```

**Step 2: Test**

```bash
# Create test data with old date
mkdir -p /tmp/compound-test/solutions/bugs
cat > /tmp/compound-test/solutions/bugs/old-bug.md << 'EOF'
---
title: "Old Bug"
created: "2025-01-01"
last_updated: "2025-01-01"
status: active
occurrence_count: 1
tags: [test]
---
# Old Bug
EOF

COMPOUND_ROOT=/tmp/compound-test bash scripts/refresh.sh 2>&1
# Expected: STALE warning for Old Bug

rm -rf /tmp/compound-test
```

**Acceptance Criteria:**
1. `refresh.sh` 扫描所有 solutions 目录
2. 超过 90 天未更新的文档标记为 STALE
3. `--auto-fix` 参数自动更新 status 为 stale
4. 输出包含统计摘要

---

## Phase 3: Platform Adapters（平台适配器）

### Task 8: Hermes Skill adapter

**Objective:** Create Hermes skill that integrates with error-learning and memory systems.

**Files:**
- Create: `platforms/hermes/SKILL.md`

**Step 1: Write Hermes skill**

```bash
cat > platforms/hermes/SKILL.md << 'HERMES_SKILL_EOF'
---
name: compound-system
description: "Post-task reflection: capture error patterns and knowledge as structured Markdown files. Three-tier cost filtering, dual-track (bug/knowledge), grep-based retrieval."
version: 1.0.0
author: Compound System
license: MIT
tags: [compound, reflection, error-learning, knowledge]
metadata:
  hermes:
    tags: [compound, reflection, error, knowledge, retrieval]
    related_skills: [error-learning, memory-management]
---

# Compound System — Hermes Integration

## When to Trigger

After completing a task that:
1. Encountered errors (especially if debugging took >5 min)
2. Discovered new patterns or knowledge
3. Made important decisions (architecture, tool selection)
4. User says "记住这个"

## How to Use

### Capture (after task)

```bash
# 1. Run rule gate
COMPOUND_ROOT=~/.hermes/compound-system
RESULT=$(bash $COMPOUND_ROOT/scripts/compound.sh reflect \
    "<outcome>" "<severity>" <duration> <retries> "<files_modified>")

# 2. If "reflect", run quick reflect
if [[ "$RESULT" == "reflect" ]]; then
    # Generate reflection (requires LLM_API_KEY)
    REFLECTION=$(bash $COMPOUND_ROOT/scripts/reflect.sh \
        "<task_description>" "<outcome>" "<severity>" "<error_messages>")

    # Write solution
    echo "$REFLECTION" | bash $COMPOUND_ROOT/scripts/write-solution.sh
fi
```

### Search (before starting a task)

```bash
# Search for known patterns
bash $COMPOUND_ROOT/scripts/search.sh "<error_description>"

# Search specific track
bash $COMPOUND_ROOT/scripts/search.sh "<query>" --track bugs --limit 5
```

### Status

```bash
bash $COMPOUND_ROOT/scripts/compound.sh status
```

## Integration with Existing Systems

- **error-learning skill**: compound-system replaces manual error capture
- **fact_store**: compound-system writes to files (grep-able), fact_store for structured queries
- **AgentMemory**: compound-system files are the source of truth, AgentMemory for semantic search
- **MEMORY.md**: compound-system auto-maintains high-value patterns section

## Cost Control

Level 0 (Rule Gate) is always free. Level 1 (Quick Reflect) costs ~$0.0002 per call.
Only trigger Level 1 when Rule Gate says "reflect".
HERMES_SKILL_EOF
```

**Acceptance Criteria:**
1. `platforms/hermes/SKILL.md` 存在且格式正确
2. Skill 定义包含触发条件、使用方法、集成说明
3. 可被 `skill_view(name='compound-system')` 加载

---

### Task 9: Claude Code adapter

**Objective:** Create CLAUDE.md integration for Claude Code.

**Files:**
- Create: `platforms/claude-code/CLAUDE.md`

**Step 1: Write CLAUDE.md**

```bash
cat > platforms/claude-code/CLAUDE.md << 'CLAUDE_EOF'
# Compound System — Claude Code Integration

## Quick Start

After completing a task with errors or important discoveries:

```bash
# Capture learning
bash ~/.hermes/compound-system/scripts/compound.sh reflect \
    "error_recovered" "medium" 300 3 "src/app.py"

# Or with full context
echo '{"outcome":"error_recovered","severity":"medium","task":"fix auth bug"}' | \
    bash ~/.hermes/compound-system/scripts/compound.sh reflect
```

## Search Before Coding

Before starting a new task, search for known patterns:

```bash
bash ~/.hermes/compound-system/scripts/search.sh "auth error"
```

## Directory Structure

```
~/.hermes/compound-system/solutions/
├── bugs/          # Error patterns with fix process
├── knowledge/     # Architecture decisions, tool choices
├── patterns/      # Generalized patterns from multiple solutions
└── CONCEPTS.md    # Project vocabulary
```

## File Format

Each solution is Markdown with YAML frontmatter:

```yaml
---
title: "Short description"
tags: [tag1, tag2, tag3]
problem_type: build_error|runtime_error|...
severity: low|medium|high|blocking
root_cause: "One-line root cause"
created: 2026-06-14
occurrence_count: 1
---
```

## Workflow

1. **After task**: Run `compound.sh reflect` to capture learnings
2. **Before task**: Run `search.sh` to find known patterns
3. **Weekly**: Run `compound.sh refresh` to clean stale docs
CLAUDE_EOF
```

**Acceptance Criteria:**
1. `platforms/claude-code/CLAUDE.md` 存在
2. 包含 Quick Start、搜索方法、目录结构、工作流说明
3. 命令可直接复制执行

---

### Task 10: Codex adapter

**Objective:** Create Codex integration instructions.

**Files:**
- Create: `platforms/codex/codex.md`

**Step 1: Write codex.md**

```bash
cat > platforms/codex/codex.md << 'CODEX_EOF'
# Compound System — Codex Integration

## Setup

Add to your Codex instructions:

```markdown
## Compound System

After completing tasks, capture learnings:

\`\`\`bash
# Reflect on task
bash ~/.hermes/compound-system/scripts/compound.sh reflect \
    "<outcome>" "<severity>" <duration> <retries> "<files>"

# Search known patterns
bash ~/.hermes/compound-system/scripts/search.sh "<query>"
\`\`\`

Solutions are stored in ~/.hermes/compound-system/solutions/
Search with: grep -rl "query" ~/.hermes/compound-system/solutions/
```

## Manual Capture

```bash
# Quick reflect (needs LLM_API_KEY)
bash ~/.hermes/compound-system/scripts/reflect.sh \
    "task description" "error_recovered" "medium" "error message"

# Write solution
echo '<json>' | bash ~/.hermes/compound-system/scripts/write-solution.sh
```

## Grep-Based Search (Zero Cost)

```bash
# Search all solutions
grep -rl "401\|expired" ~/.hermes/compound-system/solutions/

# Search bugs only
grep -rl "build_error" ~/.hermes/compound-system/solutions/bugs/

# Search by tag
grep -l "tags:.*mcp" ~/.hermes/compound-system/solutions/**/*.md
```
CODEX_EOF
```

**Acceptance Criteria:**
1. `platforms/codex/codex.md` 存在
2. 包含 setup 说明、手动捕获方法、grep 搜索方法
3. 命令无 Python 依赖

---

## Phase 4: README & Polish（文档打磨）

### Task 11: Write README.md

**Objective:** Project documentation with installation, usage, and philosophy.

**Files:**
- Create: `README.md`

**Step 1: Write README**

```bash
cat > README.md << 'README_EOF'
# Compound System

> **每次工程工作都应该让后续工作变得更容易。**

Post-task reflection system for AI coding agents. Captures error patterns and knowledge as structured Markdown files.

## Features

- **Three-tier cost filtering**: Rule Gate (free) → Quick Reflect (~$0.0002) → Deep Reflect (~$0.03)
- **Dual-track capture**: Bug Track (errors) + Knowledge Track (decisions)
- **Grep-based retrieval**: Zero-cost pre-filtering on YAML frontmatter
- **Cross-platform**: Works with Hermes, Claude Code, Codex, Cursor
- **Lifecycle management**: Staleness detection, dedup, consolidation

## Quick Start

```bash
# Install
git clone https://github.com/yourname/compound-system.git
cd compound-system
chmod +x scripts/*.sh

# Capture a learning
bash scripts/compound.sh reflect error_recovered medium 300 3 "src/app.py"

# Search for patterns
bash scripts/search.sh "401 error"

# Check status
bash scripts/compound.sh status
```

## How It Works

```
Task completes
    │
    ▼
Level 0: Rule Gate (free)
    │ needs reflection
    ▼
Level 1: Quick Reflect (~$0.0002)
    │ high value
    ▼
Level 2: Deep Reflect (~$0.03)
    │
    ▼
Write to solutions/ directory
```

## Directory Structure

```
solutions/
├── bugs/          # Error patterns
├── knowledge/     # Architecture decisions
├── patterns/      # Generalized patterns
└── CONCEPTS.md    # Vocabulary
```

## Platform Integration

| Platform | Adapter | Location |
|----------|---------|----------|
| Hermes | Skill | `platforms/hermes/SKILL.md` |
| Claude Code | CLAUDE.md | `platforms/claude-code/CLAUDE.md` |
| Codex | Instructions | `platforms/codex/codex.md` |
| Cursor | Rules | `platforms/cursor/.cursorrules` |

## Philosophy

Inspired by [Compound Engineering Plugin](https://github.com/EveryInc/compound-engineering-plugin) (18k+ stars).

Key differences:
- **Three-tier cost filtering** (CE always runs full capture)
- **Pure bash** (no Python dependency)
- **Dual-track** (bug + knowledge)
- **Grep-based retrieval** (zero-cost pre-filtering)

## License

MIT
README_EOF
```

**Acceptance Criteria:**
1. `README.md` 存在且包含所有必要章节
2. Quick Start 命令可直接执行
3. 包含与 CE Plugin 的对比

---

### Task 12: Integration test (end-to-end)

**Objective:** Full pipeline test: reflect → write → search → verify.

**Files:**
- Create: `tests/test_e2e.sh`

**Step 1: Write E2E test**

```bash
cat > tests/test_e2e.sh << 'E2E_EOF'
#!/usr/bin/env bash
# End-to-end test for Compound System

set -euo pipefail

TEST_DIR="/tmp/compound-e2e-test"
export COMPOUND_ROOT="$TEST_DIR"

# Setup
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/solutions/{bugs,knowledge,patterns}"
cp -r scripts "$TEST_DIR/"
cp -r templates "$TEST_DIR/"

PASS=0 FAIL=0

assert() {
    local desc="$1" condition="$2"
    if eval "$condition"; then
        echo "  ✅ $desc"
        ((PASS++))
    else
        echo "  ❌ $desc"
        ((FAIL++))
    fi
}

echo "=== E2E Test ==="

# Test 1: Rule Gate
echo ""
echo "1. Rule Gate"
RESULT=$(bash "$TEST_DIR/scripts/compound.sh" reflect success none 0 0 "")
assert "Simple success → skip" '[ "$RESULT" = "skip" ]'

RESULT=$(bash "$TEST_DIR/scripts/compound.sh" reflect error_recovered medium 0 0 "")
assert "Error recovered → reflect" '[ "$RESULT" = "reflect" ]'

# Test 2: Write solution (mock JSON)
echo ""
echo "2. Write Solution"
echo '{"pattern_title":"E2E Test Bug","track":"bug","error_type":"配置错误","root_cause":"test root cause","solution_summary":"test solution","tags":["e2e","test"],"reusable_pattern":true,"confidence":0.8}' | \
    bash "$TEST_DIR/scripts/write-solution.sh"

FILE_COUNT=$(find "$TEST_DIR/solutions/bugs" -name "*.md" -not -name ".gitkeep" | wc -l)
assert "Created 1 solution file" '[ "$FILE_COUNT" -eq 1 ]'

# Test 3: Dedup
echo ""
echo "3. Dedup"
echo '{"pattern_title":"E2E Test Bug","track":"bug","error_type":"配置错误","root_cause":"test root cause","solution_summary":"test solution","tags":["e2e","test"],"reusable_pattern":true,"confidence":0.8}' | \
    bash "$TEST_DIR/scripts/write-solution.sh"

FILE_COUNT=$(find "$TEST_DIR/solutions/bugs" -name "*.md" -not -name ".gitkeep" | wc -l)
assert "Still 1 file after dedup" '[ "$FILE_COUNT" -eq 1 ]'

COUNT=$(grep -h "occurrence_count" "$TEST_DIR/solutions/bugs"/*.md | head -1 | awk '{print $2}')
assert "occurrence_count is 2" '[ "$COUNT" = "2" ]'

# Test 4: Search
echo ""
echo "4. Search"
RESULT=$(bash "$TEST_DIR/scripts/search.sh" "E2E" 2>&1)
assert "Finds E2E solution" 'echo "$RESULT" | grep -q "E2E Test Bug"'

# Test 5: Status
echo ""
echo "5. Status"
RESULT=$(bash "$TEST_DIR/scripts/compound.sh" status 2>&1)
assert "Shows 1 bug" 'echo "$RESULT" | grep -q "Bugs:.*1"'

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
E2E_EOF
chmod +x tests/test_e2e.sh
```

**Step 2: Run E2E test**

```bash
bash tests/test_e2e.sh
# Expected: All passed
```

**Acceptance Criteria:**
1. E2E 测试通过：Rule Gate → Write → Dedup → Search → Status
2. 所有文件在临时目录创建，不影响真实 solutions/
3. 测试后清理临时目录

---

## Phase Summary

| Phase | Tasks | 内容 | 依赖 |
|-------|-------|------|------|
| 1 | 1-6 | Core Infrastructure | 无 |
| 2 | 7 | Lifecycle Management | Phase 1 |
| 3 | 8-10 | Platform Adapters | Phase 1 |
| 4 | 11-12 | README + E2E Test | Phase 1-3 |

**Estimated Total Time**: 4-6 hours (single developer)

**Minimum Viable Product**: Phase 1 + Task 8 (Hermes adapter) = ~3 hours
