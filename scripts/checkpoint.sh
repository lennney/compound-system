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
        CONTEXT="${6:-}"
        [[ -z "$CONTEXT" ]] && CONTEXT="{}"

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
