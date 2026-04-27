#!/bin/bash
# Module: terminal-reload
# Version: 0.2.0
# Description: Shell reload utility
# BashMod Dependencies: none

alias reload='exec "$SHELL" -c "echo \"✓ Shell reloaded\" && exec \"$SHELL\""'
