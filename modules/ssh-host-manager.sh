#!/bin/bash
# Module: ssh-host-manager
# Version: 0.6.0
# Description: Comprehensive SSH and Git host management suite
# BashMod Dependencies: none

# Global configuration (can be overridden before sourcing this module)
export CODE_BASE_DIR="${CODE_BASE_DIR:-$HOME/code}"

# Get the directory where this script is located
SSH_HOST_MANAGER_DIR="${BASH_SOURCE[0]%/*}/ssh-host-manager"

# Source all component modules
for component in "$SSH_HOST_MANAGER_DIR"/*.sh; do
    if [ -f "$component" ]; then
        source "$component"
    fi
done

unset SSH_HOST_MANAGER_DIR
