#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# The Promptorium - Interactive Installer
# Installs skills and agents for Claude Code and Cursor
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source → Destination mappings
CLAUDE_AGENTS_SRC="$SCRIPT_DIR/claude-agents"
CLAUDE_AGENTS_DST="$HOME/.claude/agents"

CLAUDE_SKILLS_SRC="$SCRIPT_DIR/claude-skills"
CLAUDE_SKILLS_DST="$HOME/.claude/commands"

CURSOR_AGENTS_SRC="$SCRIPT_DIR/coding-agents"
CURSOR_AGENTS_DST="$HOME/.cursor/agents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# CLI flags
FLAG_YES=false
FLAG_DRY_RUN=false
FLAG_DIFF=false
FLAG_CLAUDE_ONLY=false
FLAG_CURSOR_ONLY=false
FLAG_LIST=false
FLAG_FORCE=false

# Tracking
INSTALLED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${BOLD}━━━ $1 ━━━${RESET}"
    echo ""
}

print_status() {
    local status="$1"
    local name="$2"
    case "$status" in
        NEW)          echo -e "  ${GREEN}[NEW]${RESET}            $name" ;;
        UPDATE)       echo -e "  ${YELLOW}[UPDATE]${RESET}         $name" ;;
        CURRENT)      echo -e "  ${DIM}[CURRENT]${RESET}        $name" ;;
        LOCAL_MODIFIED) echo -e "  ${BLUE}[LOCAL MODIFIED]${RESET} $name" ;;
        INSTALLED)    echo -e "  ${GREEN}[INSTALLED]${RESET}      $name" ;;
        SKIPPED)      echo -e "  ${DIM}[SKIPPED]${RESET}        $name" ;;
        ERROR)        echo -e "  ${RED}[ERROR]${RESET}          $name" ;;
    esac
}

# Get file modification time as epoch seconds (cross-platform)
get_file_mtime() {
    local file="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f %m "$file"
    else
        stat -c %Y "$file"
    fi
}

# Get git commit timestamp for a file (epoch seconds)
# Returns 0 if file is not tracked by git
get_git_timestamp() {
    local file="$1"
    local ts
    ts=$(git -C "$SCRIPT_DIR" log -1 --format=%ct -- "$file" 2>/dev/null || echo "0")
    echo "${ts:-0}"
}

# Compare a single source file against installed destination
# Returns: new, updated, current, local_modified
compare_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$dst" ]]; then
        echo "new"
        return
    fi

    if diff -q "$src" "$dst" &>/dev/null; then
        echo "current"
        return
    fi

    # Files differ — use git timestamp vs installed file mtime to determine direction
    local src_ts dst_ts
    src_ts=$(get_git_timestamp "$src")
    dst_ts=$(get_file_mtime "$dst")

    if [[ "$src_ts" -gt "$dst_ts" ]]; then
        echo "updated"
    else
        echo "local_modified"
    fi
}

# Compare a skill directory (SKILL.md + references/)
# Returns: new, updated, current, local_modified
compare_skill_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    if [[ ! -d "$dst_dir" ]]; then
        echo "new"
        return
    fi

    local has_new=false
    local has_updated=false
    local has_local_modified=false
    local all_current=true

    while IFS= read -r -d '' src_file; do
        local rel_path="${src_file#"$src_dir"/}"
        local dst_file="$dst_dir/$rel_path"
        local status
        status=$(compare_file "$src_file" "$dst_file")

        case "$status" in
            new)            has_new=true; all_current=false ;;
            updated)        has_updated=true; all_current=false ;;
            local_modified) has_local_modified=true; all_current=false ;;
            current)        ;;
        esac
    done < <(find "$src_dir" -type f -print0)

    if $all_current; then
        echo "current"
    elif $has_new || $has_updated; then
        echo "updated"
    else
        echo "local_modified"
    fi
}

show_diff() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$dst" ]]; then
        echo -e "${DIM}(new file - no diff available)${RESET}"
        return
    fi

    diff --color=always -u "$dst" "$src" 2>/dev/null | head -80 || true
}

show_skill_diff() {
    local src_dir="$1"
    local dst_dir="$2"

    while IFS= read -r -d '' src_file; do
        local rel_path="${src_file#"$src_dir"/}"
        local dst_file="$dst_dir/$rel_path"
        echo -e "\n${BOLD}--- $rel_path ---${RESET}"
        show_diff "$src_file" "$dst_file"
    done < <(find "$src_dir" -type f -print0 | sort -z)
}

copy_file() {
    local src="$1"
    local dst="$2"

    local dst_dir
    dst_dir=$(dirname "$dst")
    if ! mkdir -p "$dst_dir" 2>/dev/null; then
        print_status ERROR "Failed to create directory: $dst_dir"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi

    if cp "$src" "$dst" 2>/dev/null; then
        return 0
    else
        print_status ERROR "Failed to copy: $src -> $dst"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
}

copy_skill_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    if ! mkdir -p "$dst_dir" 2>/dev/null; then
        print_status ERROR "Failed to create directory: $dst_dir"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi

    local failed=false
    while IFS= read -r -d '' src_file; do
        local rel_path="${src_file#"$src_dir"/}"
        local dst_file="$dst_dir/$rel_path"
        if ! copy_file "$src_file" "$dst_file"; then
            failed=true
        fi
    done < <(find "$src_dir" -type f -print0)

    if $failed; then
        return 1
    fi
    return 0
}

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Interactive installer for The Promptorium skills and agents.

Options:
  --help          Show this help message
  --dry-run       Show what would be installed without doing it
  --yes, -y       Skip confirmation prompts
  --diff          Show diffs for all updates
  --claude-only   Only install Claude Code items
  --cursor-only   Only install Cursor items
  --list          List all available items with status (don't install)
  --force         Overwrite even if local version is larger/modified

Examples:
  ./install.sh                  Interactive install
  ./install.sh --list           Show what's available and current status
  ./install.sh --dry-run        Preview what would be installed
  ./install.sh -y               Install everything without prompts
  ./install.sh --claude-only    Only install Claude Code agents + skills
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse CLI Arguments
# ─────────────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)         usage; exit 0 ;;
        --dry-run)      FLAG_DRY_RUN=true ;;
        --yes|-y)       FLAG_YES=true ;;
        --diff)         FLAG_DIFF=true ;;
        --claude-only)  FLAG_CLAUDE_ONLY=true ;;
        --cursor-only)  FLAG_CURSOR_ONLY=true ;;
        --list)         FLAG_LIST=true ;;
        --force)        FLAG_FORCE=true ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}"
            usage
            exit 1
            ;;
    esac
    shift
done

if $FLAG_CLAUDE_ONLY && $FLAG_CURSOR_ONLY; then
    echo -e "${RED}Cannot use --claude-only and --cursor-only together${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Tool Selection
# ─────────────────────────────────────────────────────────────────────────────

INSTALL_CLAUDE=true
INSTALL_CURSOR=true

if $FLAG_CLAUDE_ONLY; then
    INSTALL_CURSOR=false
elif $FLAG_CURSOR_ONLY; then
    INSTALL_CLAUDE=false
elif ! $FLAG_YES && ! $FLAG_LIST; then
    print_header "The Promptorium - Installer"

    echo "Select tools to install for:"
    echo ""
    echo "  1) Claude Code (agents + skills)"
    echo "  2) Cursor (agents)"
    echo "  3) Both (default)"
    echo ""
    read -r -p "Choice [3]: " tool_choice
    tool_choice="${tool_choice:-3}"

    case "$tool_choice" in
        1) INSTALL_CURSOR=false ;;
        2) INSTALL_CLAUDE=false ;;
        3) ;;
        *)
            echo -e "${RED}Invalid choice${RESET}"
            exit 1
            ;;
    esac
fi

# ─────────────────────────────────────────────────────────────────────────────
# Discovery & Status Phase
# ─────────────────────────────────────────────────────────────────────────────

# Arrays to hold discovered items
# Each entry: "type|name|status|src|dst"
declare -a ITEMS=()

discover_items() {
    # Claude Code agents
    if $INSTALL_CLAUDE && [[ -d "$CLAUDE_AGENTS_SRC" ]]; then
        for src_file in "$CLAUDE_AGENTS_SRC"/*.md; do
            [[ -f "$src_file" ]] || continue
            local name
            name=$(basename "$src_file")
            local dst_file="$CLAUDE_AGENTS_DST/$name"
            local status
            status=$(compare_file "$src_file" "$dst_file")
            ITEMS+=("claude-agent|$name|$status|$src_file|$dst_file")
        done
    fi

    # Claude Code skills
    if $INSTALL_CLAUDE && [[ -d "$CLAUDE_SKILLS_SRC" ]]; then
        for src_dir in "$CLAUDE_SKILLS_SRC"/*/; do
            [[ -d "$src_dir" ]] || continue
            local name
            name=$(basename "$src_dir")
            local dst_dir="$CLAUDE_SKILLS_DST/$name"
            local status
            status=$(compare_skill_dir "$src_dir" "$dst_dir")
            ITEMS+=("claude-skill|$name|$status|$src_dir|$dst_dir")
        done
    fi

    # Cursor agents
    if $INSTALL_CURSOR && [[ -d "$CURSOR_AGENTS_SRC" ]]; then
        for src_file in "$CURSOR_AGENTS_SRC"/*.md; do
            [[ -f "$src_file" ]] || continue
            local name
            name=$(basename "$src_file")
            local dst_file="$CURSOR_AGENTS_DST/$name"
            local status
            status=$(compare_file "$src_file" "$dst_file")
            ITEMS+=("cursor-agent|$name|$status|$src_file|$dst_file")
        done
    fi
}

discover_items

if [[ ${#ITEMS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No items found to install.${RESET}"
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Display Status Summary
# ─────────────────────────────────────────────────────────────────────────────

display_status() {
    local last_type=""
    for item in "${ITEMS[@]}"; do
        IFS='|' read -r type name status src dst <<< "$item"

        # Print section header on type change
        if [[ "$type" != "$last_type" ]]; then
            case "$type" in
                claude-agent) print_header "Claude Code Agents" ;;
                claude-skill) print_header "Claude Code Skills" ;;
                cursor-agent) print_header "Cursor Agents" ;;
            esac
            last_type="$type"
        fi

        case "$status" in
            new)            print_status NEW "$name" ;;
            updated)        print_status UPDATE "$name" ;;
            current)        print_status CURRENT "$name" ;;
            local_modified) print_status LOCAL_MODIFIED "$name" ;;
        esac
    done
}

display_status

# If --list, we're done
if $FLAG_LIST; then
    echo ""
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Item Selection
# ─────────────────────────────────────────────────────────────────────────────

# Build selection array: index -> selected (true/false)
declare -a SELECTED=()
declare -a SELECTABLE_INDICES=()

for i in "${!ITEMS[@]}"; do
    IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"
    case "$status" in
        new|updated)
            SELECTED+=("true")
            SELECTABLE_INDICES+=("$i")
            ;;
        local_modified)
            if $FLAG_FORCE; then
                SELECTED+=("true")
            else
                SELECTED+=("false")
            fi
            SELECTABLE_INDICES+=("$i")
            ;;
        current)
            if $FLAG_FORCE; then
                SELECTED+=("true")
                SELECTABLE_INDICES+=("$i")
            fi
            ;;
    esac
done

# Count actionable items
actionable_count=0
for sel in "${SELECTED[@]}"; do
    if [[ "$sel" == "true" ]]; then
        actionable_count=$((actionable_count + 1))
    fi
done

if [[ $actionable_count -eq 0 ]] && ! $FLAG_FORCE; then
    echo ""
    echo -e "${GREEN}Everything is up to date. Nothing to install.${RESET}"
    exit 0
fi

# Interactive selection (skip if --yes)
if ! $FLAG_YES; then
    echo ""
    print_header "Select Items to Install"
    echo "Enter item numbers to toggle, 'a' for all, 'n' for none, 'd' to show diffs, or 'go' to proceed:"
    echo ""

    display_selection() {
        local sel_idx=0
        for i in "${SELECTABLE_INDICES[@]}"; do
            IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"
            local marker="  "
            if [[ "${SELECTED[$sel_idx]}" == "true" ]]; then
                marker="${GREEN}x${RESET}"
            fi

            local status_tag=""
            case "$status" in
                new)            status_tag="${GREEN}NEW${RESET}" ;;
                updated)        status_tag="${YELLOW}UPDATE${RESET}" ;;
                current)        status_tag="${DIM}CURRENT${RESET}" ;;
                local_modified) status_tag="${BLUE}LOCAL MODIFIED${RESET}" ;;
            esac

            local type_label=""
            case "$type" in
                claude-agent) type_label="claude-agent" ;;
                claude-skill) type_label="claude-skill" ;;
                cursor-agent) type_label="cursor-agent" ;;
            esac

            echo -e "  [$marker] $((sel_idx + 1))) ${type_label}/${name} [${status_tag}]"
            sel_idx=$((sel_idx + 1))
        done
    }

    while true; do
        display_selection
        echo ""
        read -r -p "> " input

        case "$input" in
            go|GO|"")
                break
                ;;
            a|A)
                for i in "${!SELECTED[@]}"; do
                    SELECTED[$i]="true"
                done
                echo ""
                ;;
            n|N)
                for i in "${!SELECTED[@]}"; do
                    SELECTED[$i]="false"
                done
                echo ""
                ;;
            d|D)
                echo ""
                _sel_idx=0
                for i in "${SELECTABLE_INDICES[@]}"; do
                    if [[ "${SELECTED[$_sel_idx]}" == "true" ]]; then
                        IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"
                        if [[ "$status" == "updated" || "$status" == "local_modified" ]]; then
                            echo -e "${BOLD}=== $type/$name ===${RESET}"
                            if [[ "$type" == "claude-skill" ]]; then
                                show_skill_diff "$src" "$dst"
                            else
                                show_diff "$src" "$dst"
                            fi
                            echo ""
                        fi
                    fi
                    _sel_idx=$((_sel_idx + 1))
                done
                ;;
            *)
                # Toggle by number(s) - support space/comma separated
                for num in $(echo "$input" | tr ',' ' '); do
                    num=$(echo "$num" | tr -d ' ')
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#SELECTED[@]}" ]]; then
                        _idx=$((num - 1))
                        if [[ "${SELECTED[$_idx]}" == "true" ]]; then
                            SELECTED[$_idx]="false"
                        else
                            SELECTED[$_idx]="true"
                        fi
                    else
                        echo -e "${RED}Invalid number: $num${RESET}"
                    fi
                done
                echo ""
                ;;
        esac
    done
fi

# ─────────────────────────────────────────────────────────────────────────────
# Diff Preview (--diff flag)
# ─────────────────────────────────────────────────────────────────────────────

if $FLAG_DIFF; then
    print_header "Diffs"
    sel_idx=0
    for i in "${SELECTABLE_INDICES[@]}"; do
        if [[ "${SELECTED[$sel_idx]}" == "true" ]]; then
            IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"
            if [[ "$status" == "updated" || "$status" == "local_modified" ]]; then
                echo -e "${BOLD}=== $type/$name ===${RESET}"
                if [[ "$type" == "claude-skill" ]]; then
                    show_skill_diff "$src" "$dst"
                else
                    show_diff "$src" "$dst"
                fi
                echo ""
            fi
        fi
        sel_idx=$((sel_idx + 1))
    done
fi

# ─────────────────────────────────────────────────────────────────────────────
# Confirmation
# ─────────────────────────────────────────────────────────────────────────────

selected_count=0
for sel in "${SELECTED[@]}"; do
    if [[ "$sel" == "true" ]]; then
        selected_count=$((selected_count + 1))
    fi
done

if [[ $selected_count -eq 0 ]]; then
    echo ""
    echo -e "${YELLOW}No items selected. Nothing to install.${RESET}"
    exit 0
fi

if $FLAG_DRY_RUN; then
    print_header "Dry Run - Would Install"
    sel_idx=0
    for i in "${SELECTABLE_INDICES[@]}"; do
        if [[ "${SELECTED[$sel_idx]}" == "true" ]]; then
            IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"
            echo -e "  ${name} -> ${dst}"
        fi
        sel_idx=$((sel_idx + 1))
    done
    echo ""
    echo -e "${DIM}$selected_count item(s) would be installed.${RESET}"
    exit 0
fi

if ! $FLAG_YES; then
    echo ""
    read -r -p "Install $selected_count item(s)? [Y/n] " confirm
    confirm="${confirm:-Y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Installation Phase
# ─────────────────────────────────────────────────────────────────────────────

print_header "Installing"

sel_idx=0
for i in "${SELECTABLE_INDICES[@]}"; do
    if [[ "${SELECTED[$sel_idx]}" == "true" ]]; then
        IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"

        if [[ "$type" == "claude-skill" ]]; then
            if copy_skill_dir "$src" "$dst"; then
                print_status INSTALLED "$type/$name"
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            fi
        else
            if copy_file "$src" "$dst"; then
                print_status INSTALLED "$type/$name"
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            fi
        fi
    else
        IFS='|' read -r type name status src dst <<< "${ITEMS[$i]}"
        print_status SKIPPED "$type/$name"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    sel_idx=$((sel_idx + 1))
done

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

print_header "Summary"
echo -e "  ${GREEN}Installed:${RESET} $INSTALLED_COUNT"
echo -e "  ${DIM}Skipped:${RESET}   $SKIPPED_COUNT"
if [[ $ERROR_COUNT -gt 0 ]]; then
    echo -e "  ${RED}Errors:${RESET}    $ERROR_COUNT"
fi
echo ""
