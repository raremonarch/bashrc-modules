#!/bin/bash
# Module: git-sync
# Version: 0.2.0
# Description: Git working-state sync for Syncthing-based multi-machine workflows: git-setup, clone-repo, auto-catchup
# BashMod Dependencies: none

export BASHRCMODS_CODE_BASE_DIR="${BASHRCMODS_CODE_BASE_DIR:-$HOME/code}"
# Prevent git CLI from walking up past ~/code when discovering repos.
# Without this, `git status` in ~/code finds ~/.git (dotfiles repo).
# $HOME itself is excluded from the ceiling so git still finds ~/.git when in ~.
export GIT_CEILING_DIRECTORIES="$HOME/code"

_git_sync_mod_script="${BASH_SOURCE[0]:-$0}"
_GIT_SYNC_MOD_DIR="${_git_sync_mod_script%/*}/git-sync"
unset _git_sync_mod_script

while IFS= read -r _component; do
    source "$_component"
done < <(find "$_GIT_SYNC_MOD_DIR" -maxdepth 1 -name "*.sh" 2>/dev/null | sort)

unset _GIT_SYNC_MOD_DIR _component
