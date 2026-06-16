#!/usr/bin/env bash
# Compound System — Write Solution
# Usage: write-solution.sh <json_input>
#
# Reads JSON from stdin or argument, writes to solutions/ directory.
# Checks for duplicates before writing.

# Resolve SCRIPT_DIR for sourcing utils.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve COMPOUND_ROOT (allow override via env)
if [[ -z "${COMPOUND_ROOT:-}" ]]; then
    COMPOUND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
source "$SCRIPT_DIR/utils.sh"

TIER="session"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier) TIER="$2"; shift 2 ;;
        *) break ;;
    esac
done

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

# Determine target directory
TARGET_DIR=$(target_dir_for "$TRACK" "$TIER")
mkdir -p "$TARGET_DIR"

# Generate filename
SLUG=$(slugify "$TITLE")
FILENAME="$(date_prefix)-${SLUG}.md"
FILEPATH="$TARGET_DIR/$FILENAME"

# Check for duplicates (grep frontmatter)
EXISTING=""
for f in "$TARGET_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    EXISTING_TITLE=$(yaml_get "$f" "title" | tr -d '"')
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
severity: "${SEVERITY}"
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
