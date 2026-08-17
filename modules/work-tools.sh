#!/bin/bash
# Module: work-tools
# Version: 0.1.0
# Description: work-browser / work-rdp functions that reach into WSL over SSH via the work-wsl alias
# BashMod Dependencies: none
# ~/.bashrc.d/work-tools.sh
#
# Assumes ~/.ssh/config has a `work-wsl` Host entry already defined and
# WSL's autostart pipeline (Task Scheduler + hidden VBS wrapper + systemd
# tunnel) is up and running on EIS-IPS-F638XE2. These functions assume
# connectivity, they don't establish it.

_work_tools_check_wsl_alias() {
    if ! ssh -G work-wsl >/dev/null 2>&1; then
        echo "work-tools: 'work-wsl' Host entry not found in your SSH config." >&2
        echo "See ~/.ssh/config - work-browser/work-rdp require a working work-wsl alias." >&2
        return 1
    fi
    return 0
}

work-browser() {
    _work_tools_check_wsl_alias || return 1
    waypipe ssh work-wsl chromium-browser --ozone-platform=wayland
}

work-rdp() {
    if [ -z "$1" ]; then
        echo "Usage: work-rdp <server-name>" >&2
        return 1
    fi
    _work_tools_check_wsl_alias || return 1
    ssh -X work-wsl xfreerdp /v:"$1" /u:dmckee /cert:ignore
}
