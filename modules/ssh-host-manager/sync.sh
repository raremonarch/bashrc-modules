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
