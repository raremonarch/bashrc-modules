#!/bin/bash
# Git utilities: cloning, hook detection, p10k VCS segment

# Derive a git remote URL from the directory path convention ~/code/{org}/{repo}.
# Returns git@{org}:{org}/{repo}.git if {org} is a known SSH host alias, else fails.
_derive_remote_from_path() {
    local target="$1"
    local abs_path org repo_name
    abs_path=$(realpath -- "$target")
    repo_name=$(basename "$abs_path")
    org=$(basename "$(dirname "$abs_path")")
    grep -q "^Host ${org}$" "$HOME/.ssh/config" 2>/dev/null || return 1
    echo "git@${org}:${org}/${repo_name}.git"
}

# Check a freshly cloned repo for known hook installation mechanisms and
# offer to install them. Checks in order of specificity.
_suggest_git_hooks() {
    local repo="$1"
    local cmd="" label=""

    if [ -d "$repo/scripts/hooks" ]; then
        cmd="git config core.hooksPath scripts/hooks"
        label="scripts/hooks"
    elif [ -d "$repo/.githooks" ]; then
        cmd="git config core.hooksPath .githooks"
        label=".githooks"
    elif [ -d "$repo/.git-hooks" ]; then
        cmd="git config core.hooksPath .git-hooks"
        label=".git-hooks"
    elif [ -f "$repo/.pre-commit-config.yaml" ]; then
        cmd="pre-commit install"
        label="pre-commit"
    elif [ -f "$repo/lefthook.yml" ] || [ -f "$repo/lefthook.toml" ]; then
        cmd="lefthook install"
        label="lefthook"
    elif [ -d "$repo/.husky" ]; then
        cmd="npm run prepare"
        label="husky"
    fi

    if [ -n "$cmd" ]; then
        local full_cmd
        if [ "$repo" = "." ]; then
            full_cmd="$cmd"
        else
            full_cmd="cd $repo && $cmd"
        fi
        echo ""
        echo "  ⚙ Git hooks detected ($label)."
        printf "     Install now? (%s) [Y/n] " "$cmd"
        read -r reply
        reply="${reply:-y}"
        if [[ "$reply" =~ ^[Yy] ]]; then
            local tool="${cmd%% *}"
            if ! command -v "$tool" &>/dev/null; then
                echo ""
                echo "  ✗ '$tool' is not installed — git hooks were not set up."
                case "$tool" in
                    pre-commit)
                        echo "     Install pre-commit:  pipx install pre-commit"
                        echo "                      or: pip install pre-commit"
                        ;;
                    lefthook)
                        echo "     Install lefthook:    brew install lefthook"
                        echo "                      or: go install github.com/evilmartians/lefthook@latest"
                        ;;
                    *)
                        echo "     Please install '$tool' and then run: $full_cmd"
                        ;;
                esac
                echo "     Once installed, set up hooks with: $full_cmd"
            else
                (cd "$repo" && eval "$cmd")
            fi
        else
            echo "     Skipped. To install later: $full_cmd"
        fi
    fi
}

# Called by POWERLEVEL9K_VCS_CONTENT_EXPANSION. Returns the formatted VCS content,
# or nothing (hiding the segment) when the dotfiles repo root (~) is bleeding into
# a subdirectory that isn't itself a repo.
_git_p10k_vcs_content() {
    [[ "$VCS_STATUS_WORKDIR" == "$HOME" && "$PWD" != "$HOME" ]] && return
    local c="${P9K_CONTENT/⇣* :⇡/⇣⇡}"
    c="${c// /}"
    c="${c//:/ }"
    printf "%s" "$c"
}

function clone-repo() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: clone-repo <owner> <repo-name>"
        echo "Examples:"
        echo "  clone-repo raremonarch bashmod"
        echo "    -> git@raremonarch:raremonarch/bashmod.git (uses SSH host alias)"
        echo "    -> ~/code/raremonarch/bashmod"
        echo ""
        echo "  clone-repo EBSCOIS platform.shared.bookjacket-image-resolver"
        echo "    -> git@ebscois:EBSCOIS/platform.shared.bookjacket-image-resolver.git (uses SSH host alias)"
        echo "    -> ~/code/ebscois/platform.shared.bookjacket-image-resolver"
        return 1
    fi

    local owner="$1"
    local repo_name="$2"
    local ssh_host
    ssh_host=$(echo "$owner" | tr '[:upper:]' '[:lower:]')

    local clone_dir=""
    local has_ssh_host=false
    if grep -q "^Host $ssh_host$" "$HOME/.ssh/config" 2>/dev/null; then
        has_ssh_host=true
        while IFS= read -r line; do
            if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager.*org=${ssh_host} ]]; then
                if [[ "$line" =~ clone_dir=([^\)]+) ]]; then
                    clone_dir="${BASH_REMATCH[1]}"
                    clone_dir="${clone_dir/#\~/$HOME}"
                fi
            elif [[ "$line" =~ ^Host\ $ssh_host$ ]]; then
                break
            fi
        done < "$HOME/.ssh/config"
    fi

    local git_url
    if [ "$has_ssh_host" = true ]; then
        git_url="git@${ssh_host}:${owner}/${repo_name}.git"
    else
        git_url="git@github.com:${owner}/${repo_name}.git"
    fi

    local clone_path
    if [ -n "$clone_dir" ]; then
        clone_path="${clone_dir}/${repo_name}"
    else
        clone_path="${BASHRCMODS_CODE_BASE_DIR}/${ssh_host}/${repo_name}"
    fi

    echo "Cloning ${owner}/${repo_name}..."
    echo "  URL: $git_url"
    echo "  Path: $clone_path"

    if type ssh_load_key_for_url &>/dev/null; then
        ssh_load_key_for_url "$git_url" 2>/dev/null
    fi
    if command git clone "$git_url" "$clone_path"; then
        _suggest_git_hooks "$clone_path"
    fi
}
