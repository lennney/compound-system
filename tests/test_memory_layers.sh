#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/utils.sh"

PASS=0 FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (expected='$expected', got='$actual')"
        FAIL=$((FAIL + 1))
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
assert_eq "bug→working" "$WORKING_DIR" "$(target_dir_for bug working)"

# Test 3: all_search_dirs 输出
SEARCH_DIRS=$(all_search_dirs)
assert_eq "search dirs contains working" "true" "$(echo "$SEARCH_DIRS" | grep -q working && echo true || echo false)"
assert_eq "search dirs contains longterm" "true" "$(echo "$SEARCH_DIRS" | grep -q longterm && echo true || echo false)"
assert_eq "search dirs has 4 entries" "4" "$(echo "$SEARCH_DIRS" | wc -w)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
