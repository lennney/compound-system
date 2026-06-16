#!/usr/bin/env bash
# Compound System — Search
# Usage: search.sh <query> [--track bug|knowledge|pattern] [--limit N]
#
# Strategy:
#   Layer 1: Grep frontmatter (tags, title, problem_type) — zero cost
#   Layer 2: Grep content — zero cost

# Resolve SCRIPT_DIR for sourcing utils.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve COMPOUND_ROOT (allow override via env)
if [[ -z "${COMPOUND_ROOT:-}" ]]; then
    COMPOUND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
source "$SCRIPT_DIR/utils.sh"

QUERY="${1:?Usage: search.sh <query>}"
TRACK=""
LIMIT=5

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --track) TRACK="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Build search paths
if [[ -n "$TRACK" ]]; then
    SEARCH_PATHS=()
    case "$TRACK" in
        bug)       SEARCH_PATHS+=("$WORKING_DIR" "$SESSION_DIR/bugs") ;;
        knowledge) SEARCH_PATHS+=("$WORKING_DIR" "$SESSION_DIR/knowledge") ;;
        pattern)   SEARCH_PATHS+=("$LONGTERM_DIR/patterns") ;;
        all)       SEARCH_PATHS+=("$WORKING_DIR" "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" "$LONGTERM_DIR/patterns") ;;
    esac
else
    SEARCH_PATHS=("$WORKING_DIR" "$SESSION_DIR/bugs" "$SESSION_DIR/knowledge" "$LONGTERM_DIR/patterns")
fi

RESULTS=()

# Layer 1: Grep frontmatter (tags, title, problem_type)
for dir in "${SEARCH_PATHS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
        # Check if query matches frontmatter
        if sed -n '/^---$/,/^---$/p' "$file" | grep -qi "$QUERY"; then
            RESULTS+=("$file")
        fi
    done < <(find "$dir" -name "*.md" -not -name "CONCEPTS.md" 2>/dev/null)
done

# Layer 2: Grep content (if not enough results)
if [[ ${#RESULTS[@]} -lt $LIMIT ]]; then
    for dir in "${SEARCH_PATHS[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r file; do
            if grep -qi "$QUERY" "$file" 2>/dev/null; then
                # Avoid duplicates
                found=false
                for r in "${RESULTS[@]}"; do
                    [[ "$r" == "$file" ]] && found=true && break
                done
                $found || RESULTS+=("$file")
            fi
        done < <(find "$dir" -name "*.md" -not -name "CONCEPTS.md" 2>/dev/null)
    done
fi

# Output results
if [[ ${#RESULTS[@]} -eq 0 ]]; then
    log_warn "No solutions found for: $QUERY"
    exit 0
fi

log_info "Found ${#RESULTS[@]} solution(s) for: $QUERY"
echo ""

count=0
for file in "${RESULTS[@]}"; do
    [[ $count -ge $LIMIT ]] && break
    count=$((count + 1))

    title=$(yaml_get "$file" "title")
    severity=$(yaml_get "$file" "severity")
    tags=$(yaml_get "$file" "tags")
    created=$(yaml_get "$file" "created")

    tier_label=""
    case "$file" in
        */working/*)     tier_label=" [工作记忆]" ;;
        */session/*)     tier_label=" [短期记忆]" ;;
        */longterm/*)    tier_label=" [长期记忆]" ;;
    esac
    echo -e "${GREEN}[$count]${NC} $title$tier_label"
    echo "    File: ${file#$COMPOUND_ROOT/}"
    [[ -n "$severity" ]] && echo "    Severity: $severity"
    [[ -n "$created" ]] && echo "    Created: $created"
    echo "    Tags: $tags"
    echo ""
done
