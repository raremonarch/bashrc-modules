#!/bin/bash
# CD hook: offer to initialize synced repos that are missing .git

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

if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _git_sync_auto_setup
elif [ -n "$BASH_VERSION" ]; then
    _git_sync_last_dir=""
    _git_sync_check_dir() {
        if [ "$PWD" != "$_git_sync_last_dir" ]; then
            _git_sync_last_dir="$PWD"
            _git_sync_auto_setup
        fi
    }
    if [[ "$PROMPT_COMMAND" != *"_git_sync_check_dir"* ]]; then
        PROMPT_COMMAND="_git_sync_check_dir${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
fi
