#!/usr/bin/env bash
# refresh.sh - Knowledge base lifecycle management
# Finds stale docs, merges duplicates, updates CONCEPTS.md
# Usage: refresh.sh [--dry-run] [--force] [--days N]

set -euo pipefail

COMPOUND_ROOT="${COMPOUND_ROOT:-$HOME/compound-system}"
SOLUTIONS_DIR="${COMPOUND_ROOT}/solutions"

STALE_DAYS=90
DRY_RUN=0
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --force)   FORCE=1; shift ;;
        --days)    STALE_DAYS="$2"; shift 2 ;;
        -*)        echo "Usage: refresh.sh [--dry-run] [--force] [--days N]" >&2; exit 1 ;;
        *)         echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

source "$(dirname "$0")/utils.sh"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
NOW=$(date +%s)

# --- Stage 1: Find stale docs ---
echo "=== Staleness Report ==="
echo "Threshold: ${STALE_DAYS} days"
echo "Mode: $([ "$DRY_RUN" = 1 ] && echo "DRY RUN" || echo "APPLY")"
echo ""

STALE_COUNT=0
FRESH_COUNT=0
STALE_FILES=()

while IFS= read -r filepath; do
    [[ ! -f "$filepath" ]] && continue
    
    # Parse YAML frontmatter
    in_frontmatter=0
    last_updated=""
    severity=""
    freq=""
    
    while IFS= read -r line; do
        if [[ "$line" = "---" ]]; then
            in_frontmatter=$((in_frontmatter + 1))
            [[ "$in_frontmatter" -eq 2 ]] && break
            continue
        fi
        [[ "$in_frontmatter" -ne 1 ]] && continue
        
        # Extract fields, strip quotes
        case "$line" in
            last_updated:*)
                last_updated=$(echo "$line" | cut -d: -f2- | tr -d ' "')
                ;;
            severity:*)
                severity=$(echo "$line" | cut -d: -f2- | tr -d ' "')
                ;;
            occurrence_count:*)
                freq=$(echo "$line" | cut -d: -f2- | tr -d ' "')
                ;;
        esac
    done < "$filepath"
    
    [[ -z "$last_updated" ]] && continue
    
    last_updated_epoch=$(date -d "$last_updated" +%s 2>/dev/null || echo 0)
    [[ "$last_updated_epoch" = 0 ]] && continue
    
    days_stale=$(( (NOW - last_updated_epoch) / 86400 ))
    freq=${freq:-1}
    severity=${severity:-medium}
    
    if [[ "$days_stale" -gt "$STALE_DAYS" ]]; then
        # Score: high freq + high severity = keep
        score=0
        [[ "$freq" -ge 3 ]] && score=$((score + 2))
        [[ "$severity" = "critical" ]] && score=$((score + 3))
        [[ "$severity" = "high" ]] && score=$((score + 1))
        
        if [[ "$score" -ge 3 ]]; then
            echo "  KEEP (score=$score): $(basename "$filepath") — last ${days_stale}d ago, freq=$freq, sev=$severity"
            FRESH_COUNT=$((FRESH_COUNT + 1))
        else
            echo "  STALE: $(basename "$filepath") — last ${days_stale}d ago, freq=$freq, sev=$severity"
            STALE_COUNT=$((STALE_COUNT + 1))
            STALE_FILES+=("$filepath")
        fi
    else
        FRESH_COUNT=$((FRESH_COUNT + 1))
    fi
done < <(find "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" -name "*.md" -not -name "CONCEPTS.md" 2>/dev/null)

echo ""
echo "Fresh: $FRESH_COUNT | Stale: $STALE_COUNT"
echo ""

# --- Stage 1b: Archive working docs (>1 day) ---
WORKING_ARCHIVE=0
mkdir -p "$SOLUTIONS_DIR/.archive"
if [[ -d "$WORKING_DIR" ]]; then
    for file in "$WORKING_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        CREATED=$(grep -m1 "^created:" "$file" 2>/dev/null | sed 's/^created: *//' | tr -d '"')
        [[ -z "$CREATED" ]] && continue
        created_epoch=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)
        [[ "$created_epoch" = 0 ]] && continue
        days_old=$(( (NOW - created_epoch) / 86400 ))
        if [[ "$days_old" -ge 1 ]]; then
            echo "  WORKING→ARCHIVE: $(basename "$file") — ${days_old}d old"
            WORKING_ARCHIVE=$((WORKING_ARCHIVE + 1))
            [[ "$DRY_RUN" = 0 ]] && mv "$file" "$SOLUTIONS_DIR/.archive/"
        fi
    done
fi

# --- Stage 1c: Report longterm (no expiry) ---
LONGTERM_COUNT=0
if [[ -d "$LONGTERM_DIR/patterns" ]]; then
    LONGTERM_COUNT=$(find "$LONGTERM_DIR/patterns" -name "*.md" 2>/dev/null | wc -l)
    [[ "$LONGTERM_COUNT" -gt 0 ]] && echo "  Longterm (permanent): $LONGTERM_COUNT patterns"
fi

# --- Stage 2: Report duplicates ---
echo "=== Duplicate Check ==="
declare -A TITLE_MAP
while IFS= read -r filepath; do
    [[ ! -f "$filepath" ]] && continue
    title=$(grep -m1 "^title:" "$filepath" 2>/dev/null | sed 's/^title: *//' | tr -d '"')
    [[ -z "$title" ]] && continue
    if [[ -n "${TITLE_MAP[$title]:-}" ]]; then
        echo "  DUPLICATE: '$title'"
        echo "    - ${TITLE_MAP[$title]}"
        echo "    - $filepath"
    else
        TITLE_MAP["$title"]="$filepath"
    fi
done < <(find "$SOLUTIONS_DIR" -name "*.md" -not -name "CONCEPTS.md" -not -path "*/.archive/*" 2>/dev/null)
echo ""

# --- Stage 3: Archive stale docs ---
if [[ "$STALE_COUNT" -gt 0 && "$DRY_RUN" = 0 ]]; then
    echo "=== Archiving ==="
    mkdir -p "$SOLUTIONS_DIR/.archive"
    for stale_file in "${STALE_FILES[@]}"; do
        if [[ -f "$stale_file" ]]; then
            mv "$stale_file" "$SOLUTIONS_DIR/.archive/"
            echo "  Archived: $(basename "$stale_file")"
        fi
    done
    echo ""
fi

# --- Stage 4: Update CONCEPTS.md ---
echo "=== Updating CONCEPTS.md ==="
working_count=$(find "$WORKING_DIR" -name "*.md" 2>/dev/null | wc -l)
session_count=$(find "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" -name "*.md" 2>/dev/null | wc -l)
longterm_count=$(find "$LONGTERM_DIR/patterns" -name "*.md" 2>/dev/null | wc -l)
total_solutions=$((working_count + session_count + longterm_count))

cat > "$SOLUTIONS_DIR/CONCEPTS.md" << EOF
---
last_updated: $(timestamp)
total_solutions: $total_solutions
stale_count: $STALE_COUNT
refresh_interval_days: $STALE_DAYS
---

# CONCEPTS.md — System Vocabulary

Maintained by \`refresh.sh\`. Do not edit manually.

## Categories
- bugs/: Error patterns and fixes
- knowledge/: Architecture decisions and best practices
- patterns/: Reusable solutions

## Stats
- Total solutions: $total_solutions
- Stale documents: $STALE_COUNT
- Last refresh: $(timestamp)
EOF

echo "  Updated CONCEPTS.md (total: $total_solutions solutions)"
echo ""

# --- Summary ---
echo "=== Refresh Complete ==="
echo "Stale found: $STALE_COUNT"
echo "Fresh kept:  $FRESH_COUNT"
echo "Archived:    $([ "$DRY_RUN" = 1 ] && echo "0 (dry run)" || echo "$STALE_COUNT")"
