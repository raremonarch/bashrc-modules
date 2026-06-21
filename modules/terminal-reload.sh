#!/bin/bash
# Module: terminal-reload
# Version: 0.3.0
# Description: Shell reload utility
# BashMod Dependencies: none

reload() { exec "$SHELL" -c "echo '✓ Shell reloaded' && exec \"$SHELL\""; }
