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
