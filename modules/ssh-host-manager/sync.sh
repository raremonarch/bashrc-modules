#!/bin/bash
# CD and startup hooks: initialize synced repos missing .git, catch up repos behind origin

_git_sync_auto_setup() {
    [ "${BASHRCMODS_GIT_SYNC_AUTO_SETUP:-1}" = "0" ] && return
    [ -d ".git" ] && return

    local remote_url
    remote_url=$(_derive_remote_from_path "." 2>/dev/null) || return

    printf "\n  ⚠ No .git here — initialize from %s? [Y/n] " "$remote_url"
    local reply
    read -r reply
    reply="${reply:-y}"
    echo ""
    [[ "$reply" =~ ^[Yy] ]] && git-setup
}

# For already-initialized repos: if behind origin and working tree already matches
# (i.e. Syncthing synced the files), fast-forward silently. If diverged, warn.
# Throttled: skips the network fetch if FETCH_HEAD is less than 5 minutes old.
_git_sync_catchup() {
    [ "${BASHRCMODS_GIT_SYNC_CATCHUP:-1}" = "0" ] && return
    [ -d ".git" ] || return 0

    local fetch_head=".git/FETCH_HEAD"
    if [ -f "$fetch_head" ]; then
        local now mtime age
        now=$(date +%s)
        mtime=$(stat -c %Y "$fetch_head" 2>/dev/null) || return 0
        age=$(( now - mtime ))
        [ "$age" -lt 300 ] && return 0
    fi

    git fetch origin --quiet 2>/dev/null || return 0

    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return 0

    local behind ahead
    behind=$(git rev-list --count HEAD.."origin/$branch" 2>/dev/null) || return 0
    [ "$behind" -eq 0 ] && return 0

    ahead=$(git rev-list --count "origin/$branch"..HEAD 2>/dev/null) || return 0
    if [ "$ahead" -gt 0 ]; then
        echo "[ssh-host-manager] diverged from origin/$branch (+$ahead local, +$behind remote) — resolve manually" >&2
        return 0
    fi

    if git diff --quiet "origin/$branch" 2>/dev/null; then
        echo "[ssh-host-manager] fast-forwarding $behind commit(s) to origin/$branch"
        git reset --hard "origin/$branch" --quiet
    else
        echo "[ssh-host-manager] behind origin/$branch by $behind commit(s), working tree differs — run 'git pull'" >&2
    fi
}

_git_sync_check() {
    _git_sync_auto_setup
    _git_sync_catchup
}

if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _git_sync_check
elif [ -n "$BASH_VERSION" ]; then
    _git_sync_last_dir=""
    _git_sync_check_dir() {
        if [ "$PWD" != "$_git_sync_last_dir" ]; then
            _git_sync_last_dir="$PWD"
            _git_sync_check
        fi
    }
    if [[ "$PROMPT_COMMAND" != *"_git_sync_check_dir"* ]]; then
        PROMPT_COMMAND="_git_sync_check_dir${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
fi

# Run once at shell startup to catch terminals opened directly inside a repo dir
_git_sync_check
