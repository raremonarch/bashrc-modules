#!/bin/bash
# Module: pyenv
# Version: 0.1.0
# Description: Pyenv initialization and configuration
# BashMod Dependencies: none
# pyenv configuration - managed by kitbash

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# Initialize pyenv
if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi
