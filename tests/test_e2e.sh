#!/usr/bin/env bash
# test_e2e.sh - End-to-end integration tests for Compound System
# Tests: Rule Gate → Reflect → Search → Write → Refresh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_DIR/test_e2e_tmp"
SOLUTIONS_DIR="$TEST_DIR/solutions"

# Setup
setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$SOLUTIONS_DIR"/{working,session/{bugs,knowledge},longterm/patterns}
    export COMPOUND_ROOT="$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

passed=0
failed=0

assert() {
    local desc="$1" result="$2" expected="$3"
    if [[ "$result" = "$expected" ]]; then
        echo "  ✅ $desc"
        passed=$((passed + 1))
    else
        echo "  ❌ $desc (expected '$expected', got '$result')"
        failed=$((failed + 1))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  ✅ $desc"
        passed=$((passed + 1))
    else
        echo "  ❌ $desc (missing '$needle')"
        failed=$((failed + 1))
    fi
}

echo "=== E2E Integration Tests ==="
echo ""

# --- Test 1: Write → Search roundtrip ---
echo "Test 1: Write → Search roundtrip"
setup

# Write a solution
cat > "$SOLUTIONS_DIR/session/bugs/2026-06-14-api-401.md" << 'SOL'
---
title: "API 401 Error"
module: "lark-cli"
tags: [auth, 401, api]
problem_type: "bug"
severity: "high"
root_cause: "API key expired"
solution: "Rotate key"
created: "2026-06-14"
last_updated: "2026-06-14"
occurrence_count: 1
status: active
---

# API 401 Error

The API returned 401 Unauthorized.
SOL

# Search for it
result=$("$PROJECT_DIR/scripts/search.sh" "auth" 2>&1 || true)
assert_contains "Found by tag 'auth'" "$result" "api-401"

# Search by error code
result=$("$PROJECT_DIR/scripts/search.sh" "401" 2>&1 || true)
assert_contains "Found by error code '401'" "$result" "api-401"

# Search by module
result=$("$PROJECT_DIR/scripts/search.sh" "lark-cli" 2>&1 || true)
assert_contains "Found by module 'lark-cli'" "$result" "api-401"

teardown
echo ""

# --- Test 2: Search returns nothing for unknown ---
echo "Test 2: Search returns nothing for unknown"
setup

cat > "$SOLUTIONS_DIR/session/bugs/2026-06-14-api-401.md" << 'SOL'
---
title: "API 401 Error"
module: "lark-cli"
tags: [auth, 401, api]
problem_type: "bug"
severity: "high"
root_cause: "API key expired"
solution: "Rotate key"
created: "2026-06-14"
last_updated: "2026-06-14"
occurrence_count: 1
status: active
---

# API 401 Error
SOL

result=$("$PROJECT_DIR/scripts/search.sh" "nonexistent_error_xyz" 2>&1 || true)
if echo "$result" | grep -q "No solutions found"; then
    echo "  ✅ No results for unknown query"
    passed=$((passed + 1))
else
    echo "  ❌ Expected 'No solutions found' but got: $result"
    failed=$((failed + 1))
fi

teardown
echo ""

# --- Test 3: Write dedup increments count ---
echo "Test 3: Write dedup increments count"
setup

# First write
cat > "$SOLUTIONS_DIR/session/bugs/2026-06-14-dedup-test.md" << 'SOL'
---
title: "Dedup Test Bug"
module: "test"
tags: [test]
problem_type: "bug"
severity: "medium"
root_cause: "test"
solution: "test"
created: "2026-06-14"
last_updated: "2026-06-14"
occurrence_count: 1
status: active
---

# Dedup Test
SOL

# Second write (should increment)
JSON_INPUT='{"pattern_title": "Dedup Test Bug", "track": "bug", "error_type": "bug", "tags": ["test"], "severity": "medium", "root_cause": "test root cause", "solution_summary": "test solution"}'
"$PROJECT_DIR/scripts/write-solution.sh" "$JSON_INPUT" 2>&1 || true

count=$(grep -m1 "occurrence_count:" "$SOLUTIONS_DIR/session/bugs/2026-06-14-dedup-test.md" | awk '{print $2}')
assert "occurrence_count incremented to 2" "$count" "2"

teardown
echo ""

# --- Test 4: Refresh detects stale ---
echo "Test 4: Refresh detects stale"
setup

# Create fresh doc
cat > "$SOLUTIONS_DIR/session/bugs/fresh.md" << 'SOL'
---
title: "Fresh Bug"
module: "test"
tags: [test]
problem_type: "bug"
severity: "low"
root_cause: "test"
solution: "test"
created: "2026-06-14"
last_updated: "2026-06-14"
occurrence_count: 1
status: active
---

# Fresh Bug
SOL

# Create stale doc
cat > "$SOLUTIONS_DIR/session/bugs/stale.md" << 'SOL'
---
title: "Stale Bug"
module: "test"
tags: [test]
problem_type: "bug"
severity: "low"
root_cause: "test"
solution: "test"
created: "2025-01-01"
last_updated: "2025-01-01"
occurrence_count: 1
status: active
---

# Stale Bug
SOL

result=$("$PROJECT_DIR/scripts/refresh.sh" --dry-run --days 3 2>&1 || true)
assert_contains "Detected stale doc" "$result" "STALE: stale.md"
assert_contains "Kept fresh doc" "$result" "Fresh: 1"

# Test actual archive
"$PROJECT_DIR/scripts/refresh.sh" --days 3 2>&1 || true
if [[ -f "$SOLUTIONS_DIR/.archive/stale.md" ]]; then
    echo "  ✅ Stale doc archived"
    passed=$((passed + 1))
else
    echo "  ❌ Stale doc not archived"
    failed=$((failed + 1))
fi
if [[ ! -f "$SOLUTIONS_DIR/session/bugs/stale.md" ]]; then
    echo "  ✅ Stale doc removed from bugs/"
    passed=$((passed + 1))
else
    echo "  ❌ Stale doc still in bugs/"
    failed=$((failed + 1))
fi

teardown
echo ""

# --- Test 5: CONCEPTS.md updated ---
echo "Test 5: CONCEPTS.md updated"
setup

cat > "$SOLUTIONS_DIR/session/bugs/test1.md" << 'SOL'
---
title: "Test 1"
module: "test"
tags: [test]
problem_type: "bug"
severity: "low"
root_cause: "test"
solution: "test"
created: "2026-06-14"
last_updated: "2026-06-14"
occurrence_count: 1
status: active
---

# Test 1
SOL

"$PROJECT_DIR/scripts/refresh.sh" --dry-run 2>&1 || true
total=$(grep "total_solutions:" "$SOLUTIONS_DIR/CONCEPTS.md" | awk '{print $2}')
assert "CONCEPTS.md shows 1 solution" "$total" "1"

teardown
echo ""

# --- Summary ---
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"
echo ""
[[ $failed -eq 0 ]] && echo "🎉 All tests passed!" || echo "❌ Some tests failed"
exit $failed
