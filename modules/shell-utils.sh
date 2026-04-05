#!/bin/bash
# Module: shell-utils
# Version: 0.1.0
# Description: Shell introspection utilities
# BashMod Dependencies: none

export BASHRCMODS_MODULES_DIR="${BASHRCMODS_MODULES_DIR:-$HOME/.bashrc.d}"

# Pretty-print all aliases and functions defined across sourced shell modules.
# Scans BASHRCMODS_MODULES_DIR (default: ~/.bashrc.d) for .sh files.
# Usage: aliases [search]
function aliases() {
    local search="${1:-}"
    local dir="$BASHRCMODS_MODULES_DIR"

    if [ ! -d "$dir" ]; then
        echo "No directory found at $dir (set BASHRCMODS_MODULES_DIR to override)"
        return 1
    fi

    local bold="" reset="" dim="" cyan="" yellow=""
    if [ -t 1 ]; then
        bold="\033[1m"
        reset="\033[0m"
        dim="\033[2m"
        cyan="\033[36m"
        yellow="\033[33m"
    fi

    local found_any=false

    while IFS= read -r file; do
        local -a file_aliases=()
        local -a file_functions=()

        # Extract alias names
        while IFS= read -r name; do
            [ -z "$name" ] && continue
            [[ "$name" == _* ]] && continue
            [[ -z "$search" || "$name" == *"$search"* ]] && file_aliases+=("$name")
        done < <(grep -E '^[[:space:]]*alias [^=]+=' "$file" \
            | sed -E "s/^[[:space:]]*alias +([^=[:space:]]+)=.*/\1/")

        # Extract function names (handles: "function foo", "function foo()", "foo()")
        while IFS= read -r name; do
            [ -z "$name" ] && continue
            [[ "$name" == _* ]] && continue
            [[ -z "$search" || "$name" == *"$search"* ]] && file_functions+=("$name")
        done < <(grep -E '^[[:space:]]*(function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_-]+|[a-zA-Z_][a-zA-Z0-9_-]+[[:space:]]*\(\))' "$file" \
            | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_-]+)[[:space:](\{].*/\2/')

        if [ ${#file_aliases[@]} -gt 0 ] || [ ${#file_functions[@]} -gt 0 ]; then
            found_any=true
            printf "\n${bold}${cyan}%s${reset}\n" "$(basename "$file")"

            for name in "${file_aliases[@]}"; do
                printf "  ${yellow}alias${reset}  %s\n" "$name"
            done
            for name in "${file_functions[@]}"; do
                printf "  ${dim}fn${reset}     %s\n" "$name"
            done
        fi
    done < <(find "$dir" -maxdepth 2 -name "*.sh" | sort)

    if [ "$found_any" = false ]; then
        if [ -n "$search" ]; then
            echo "No aliases or functions matching '$search' found in $dir"
        else
            echo "No aliases or functions found in $dir"
        fi
        return 1
    fi

    echo ""
}
