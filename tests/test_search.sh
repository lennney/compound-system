#!/usr/bin/env bash
COMPOUND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$COMPOUND_ROOT/scripts/utils.sh"

PASS=0 FAIL=0

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (expected '$expected' in output)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Search Tests ==="

# Create test data
TEST_DIR="/tmp/compound-search-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/solutions"/{working,session/{bugs,knowledge},longterm/patterns}

cat > "$TEST_DIR/solutions/session/bugs/test-401.md" << 'EOF'
---
title: "API 401 endpoint mismatch"
tags: [401, expired-key, wrong-endpoint]
problem_type: build_error
severity: high
---
# Test
EOF

# Test 1: Search for 401
RESULT=$(COMPOUND_ROOT="$TEST_DIR" bash "$COMPOUND_ROOT/scripts/search.sh" "401" --limit 5 2>&1)
assert_contains "Finds 401 error" "API 401 endpoint mismatch" "$RESULT"

# Test 2: Shows severity
assert_contains "Shows severity" "high" "$RESULT"

# Test 3: No results
RESULT=$(COMPOUND_ROOT="$TEST_DIR" bash "$COMPOUND_ROOT/scripts/search.sh" "nonexistent" --limit 5 2>&1)
assert_contains "Shows warning for no results" "No solutions found" "$RESULT"

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
