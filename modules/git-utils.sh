#!/bin/bash
# Module: git-utils
# Version: 0.4.0
# Description: Git utilities: SSH-aware clone-repo, post-clone hook detection, p10k VCS segment
# BashMod Dependencies: none

export BASHRCMODS_CODE_BASE_DIR="${BASHRCMODS_CODE_BASE_DIR:-$HOME/code}"

_git_utils_mod_script="${BASH_SOURCE[0]:-$0}"
_GIT_UTILS_MOD_DIR="${_git_utils_mod_script%/*}/git-utils"
unset _git_utils_mod_script

while IFS= read -r _component; do
    source "$_component"
done < <(find "$_GIT_UTILS_MOD_DIR" -maxdepth 1 -name "*.sh" 2>/dev/null | sort)

unset _GIT_UTILS_MOD_DIR _component
