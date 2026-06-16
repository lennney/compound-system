#!/usr/bin/env bash
# Compound System — Main Entry Point
# Usage: compound.sh <action> [args]
#
# Actions:
#   reflect <outcome> <severity> <duration> <retries> <files_modified>
#   capture <json>       — write reflection to solutions/
#   search <query>
#   refresh
#   status

# Resolve COMPOUND_ROOT
if [[ -z "${COMPOUND_ROOT:-}" ]]; then
    COMPOUND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$COMPOUND_ROOT/scripts/utils.sh"

# Level 0: Rule Gate — decide if reflection is needed
# Args: outcome severity duration retries files_modified
should_reflect() {
    local outcome="$1" severity="$2" duration="$3" retries="$4" files_modified="${5:-}"

    # Rule 1: Error recovered → ALWAYS reflect
    if [[ "$outcome" == "error_recovered" ]]; then
        echo "reflect"
        return
    fi

    # Rule 2: Error unresolved → ALWAYS reflect
    if [[ "$outcome" == "error_unresolved" ]]; then
        echo "reflect"
        return
    fi

    # Rule 3: High severity → ALWAYS reflect
    if [[ "$severity" == "high" || "$severity" == "blocking" ]]; then
        echo "reflect"
        return
    fi

    # Rule 4: Long debug (>5 min) → reflect
    if [[ "$duration" -gt 300 ]]; then
        echo "reflect"
        return
    fi

    # Rule 5: High retry (>=3) → reflect
    if [[ "$retries" -ge 3 ]]; then
        echo "reflect"
        return
    fi

    # Rule 6: Modified important file → reflect
    local important_files="MEMORY.md|SKILL.md|config.yaml|AGENTS.md|CLAUDE.md"
    if echo "$files_modified" | grep -qE "$important_files"; then
        echo "reflect"
        return
    fi

    # Rule 7: Success + no other flags → skip
    if [[ "$outcome" == "success" && "$severity" == "none" ]]; then
        echo "skip"
        return
    fi

    # Default: skip
    echo "skip"
}

# Only run main entry when executed directly (not when sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        reflect)
            outcome="${2:-success}"
            severity="${3:-none}"
            duration="${4:-0}"
            retries="${5:-0}"
            files="${6:-}"
            result=$(should_reflect "$outcome" "$severity" "$duration" "$retries" "$files")
            echo "$result"
            ;;
        capture)
            shift
            bash "$COMPOUND_ROOT/scripts/write-solution.sh" "$@"
            ;;
        search)
            shift
            bash "$COMPOUND_ROOT/scripts/search.sh" "$@"
            ;;
        checkpoint)
            shift
            bash "$(dirname "$0")/checkpoint.sh" "$@"
            ;;
        refresh)
            bash "$COMPOUND_ROOT/scripts/refresh.sh"
            ;;
        status)
            log_info "Memory Layers:"
            echo "  Working (临时):  $(count_solutions "$WORKING_DIR")"
            echo "  Session (短期):"
            echo "    Bugs:      $(count_solutions "$SESSION_DIR/bugs")"
            echo "    Knowledge: $(count_solutions "$SESSION_DIR/knowledge")"
            echo "  Longterm (长期):"
            echo "    Patterns:  $(count_solutions "$LONGTERM_DIR/patterns")"
            total=$(count_solutions "$WORKING_DIR")
            total=$((total + $(count_solutions "$SESSION_DIR/bugs")))
            total=$((total + $(count_solutions "$SESSION_DIR/knowledge")))
            total=$((total + $(count_solutions "$LONGTERM_DIR/patterns")))
            echo "  ──────────────"
            echo "  Total: $total"
            ;;
        help|*)
            echo "Compound System — Post-Task Reflection"
            echo ""
            echo "Usage: compound.sh <action> [args]"
            echo ""
            echo "Actions:"
            echo "  reflect <outcome> <severity> <duration> <retries> <files>"
            echo "  capture <json>       — write reflection to solutions/"
            echo "  search <query>"
            echo "  checkpoint <action> — manage task checkpoints"
            echo "    save <id> <phase> <completed> <pending> [context]"
            echo "    load <id>"
            echo "    list"
            echo "    clear <id>"
            echo "  refresh"
            echo "  status"
            ;;
    esac
fi
