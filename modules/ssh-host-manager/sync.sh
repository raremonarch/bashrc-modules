#!/bin/bash
# Syncthing git repository restoration

# Nudge the user to run git-setup when entering a directory that has a
# .gitremote but no .git folder. On by default; set BASHRCMODS_GIT_SYNC_AUTO_NUDGE=0
# to disable.
_git_sync_nudge() {
    [ "${BASHRCMODS_GIT_SYNC_AUTO_NUDGE:-1}" = "0" ] && return
    [ -f ".gitremote" ] && [ ! -d ".git" ] || return
    echo "  ⚠ No .git here — run 'git-setup' to initialize this synced repo."
}

# Register the nudge with the shell's directory-change hook
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _git_sync_nudge
elif [ -n "$BASH_VERSION" ]; then
    if [[ "$PROMPT_COMMAND" != *"_git_sync_nudge"* ]]; then
        PROMPT_COMMAND="_git_sync_nudge${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
fi


# Restore a git repository that was synced without its .git folder.
# Reads the remote URL and default branch from a .gitremote file if present,
# otherwise prompts for host alias, owner, and repo name to construct the URL.
#
# The .gitremote file is created automatically by clone-repo. It stores:
#   Line 1: remote URL
#   Line 2: default branch name
#
# Usage: git-setup [path]
function git-setup() {
    local target="${1:-.}"
    target="${target%/}"

    if [ -d "$target/.git" ]; then
        echo "Error: '$target' is already a git repository"
        return 1
    fi

    local remote_url default_branch

    if [ -f "$target/.gitremote" ]; then
        remote_url=$(sed -n '1p' "$target/.gitremote")
        default_branch=$(sed -n '2p' "$target/.gitremote")
        if [ -z "$remote_url" ]; then
            echo "Error: .gitremote file is empty or malformed"
            return 1
        fi
    else
        echo "No .gitremote file found in '$target'."
        echo ""
        local host_alias owner repo_name
        read -r -p "  Host alias (e.g. raremonarch): " host_alias
        [ -z "$host_alias" ] && { echo "Error: host alias is required"; return 1; }
        read -r -p "  Repo owner (e.g. raremonarch): " owner
        [ -z "$owner" ] && { echo "Error: repo owner is required"; return 1; }
        local default_repo_name
        default_repo_name=$(basename "$target")
        read -r -p "  Repo name [$default_repo_name]: " repo_name
        repo_name="${repo_name:-$default_repo_name}"
        remote_url="git@${host_alias}:${owner}/${repo_name}.git"
        echo ""
    fi

    [ -z "$default_branch" ] && default_branch="main"

    local target_label
    [ "$target" = "." ] && target_label="current directory" || target_label="'$target'"
    echo "Setting up git repository in $target_label..."
    echo "  Remote: $remote_url"
    echo "  Branch: $default_branch"

    # Load SSH key if the function is available
    if type ssh_load_key_for_url &>/dev/null; then
        ssh_load_key_for_url "$remote_url" 2>/dev/null
    fi

    git -C "$target" init || return 1
    git -C "$target" remote add origin "$remote_url" || return 1
    git -C "$target" fetch origin || return 1

    # Wire up the branch ref without touching the working tree
    git -C "$target" symbolic-ref HEAD "refs/heads/$default_branch"
    git -C "$target" update-ref "refs/heads/$default_branch" "refs/remotes/origin/$default_branch"

    # Reset the index to match HEAD — leaves working tree files intact
    git -C "$target" reset

    # Write .gitremote so future syncs to other machines can use git-setup automatically
    printf "%s\n%s\n" "$remote_url" "$default_branch" > "$target/.gitremote"

    # Suggest hook setup if any hook patterns are detected
    if type _suggest_git_hooks &>/dev/null; then
        _suggest_git_hooks "$target"
    fi

    echo ""
    echo "Done. Run 'git status' to see any uncommitted changes."
}
