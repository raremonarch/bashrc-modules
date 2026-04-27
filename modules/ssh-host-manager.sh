#!/bin/bash
# Module: ssh-host-manager
# Version: 0.7.5
# Description: Comprehensive SSH and Git host management suite
# BashMod Dependencies: none

# Global configuration (can be overridden before sourcing this module)
export BASHRCMODS_CODE_BASE_DIR="${BASHRCMODS_CODE_BASE_DIR:-$HOME/code}"

# Get the directory where this script is located (BASH_SOURCE[0] in bash, $0 in zsh)
_ssh_hm_script="${BASH_SOURCE[0]:-$0}"
SSH_HOST_MANAGER_DIR="${_ssh_hm_script%/*}/ssh-host-manager"
unset _ssh_hm_script

# Source all component modules (use find to avoid nullglob errors in zsh)
while IFS= read -r component; do
    source "$component"
done < <(find "$SSH_HOST_MANAGER_DIR" -maxdepth 1 -name "*.sh" 2>/dev/null | sort)

unset SSH_HOST_MANAGER_DIR
