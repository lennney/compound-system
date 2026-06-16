#!/usr/bin/env bash
COMPOUND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$COMPOUND_ROOT/scripts/utils.sh"
source "$COMPOUND_ROOT/scripts/compound.sh"

PASS=0 FAIL=0

assert_reflect() {
    local desc="$1" expect="$2" result="$3"
    if [[ "$result" == "$expect" ]]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (expected=$expect, got=$result)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Rule Gate Tests ==="

# Test 1: Simple success, no errors → skip
result=$(should_reflect "success" "none" 0 0 "")
assert_reflect "Simple success → skip" "skip" "$result"

# Test 2: Error recovered → reflect
result=$(should_reflect "error_recovered" "medium" 0 0 "")
assert_reflect "Error recovered → reflect" "reflect" "$result"

# Test 3: Error unresolved → reflect
result=$(should_reflect "error_unresolved" "high" 0 0 "")
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
result=$(should_reflect "success" "none" 0 0 "MEMORY.md")
assert_reflect "Modified MEMORY.md → reflect" "reflect" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
