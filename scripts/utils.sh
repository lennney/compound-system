#!/usr/bin/env bash
# Compound System — Shared Utilities

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths — only set if not already defined
if [[ -z "${COMPOUND_ROOT:-}" ]]; then
    COMPOUND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export COMPOUND_ROOT
SOLUTIONS_DIR="${COMPOUND_ROOT}/solutions"
export SOLUTIONS_DIR

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
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | head -1 | sed "s/^${key}: *//" || true
}

# Count solutions in a directory
count_solutions() {
    local dir="$1"
    find "$dir" -name "*.md" -not -name "CONCEPTS.md" -not -name ".gitkeep" 2>/dev/null | wc -l
}

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

# Checkpoint 目录
CHECKPOINT_DIR="${COMPOUND_ROOT}/.checkpoints"
