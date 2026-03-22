#!/bin/bash
# Module: system-reload
# Version: 0.1.1
# Description: Shell reload utility
# BashMod Dependencies: none

alias reload='exec "$SHELL" -c "echo \"✓ Shell reloaded\" && exec \"$SHELL\""'
