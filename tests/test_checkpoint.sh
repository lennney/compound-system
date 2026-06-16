#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/utils.sh"

# Standalone fallback
CHECKPOINT_DIR="${CHECKPOINT_DIR:-${COMPOUND_ROOT}/.checkpoints}"

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
