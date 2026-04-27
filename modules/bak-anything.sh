#!/bin/bash
# Module: bak-anything
# Version: 0.2.0
# Description: Backup and restore files with .bak extension
# BashMod Dependencies: none

function bak() {
    if [ -z "$1" ]; then
        echo "Usage: bak <file>       - Create backup (add .bak extension)"
        echo "       bak -u <file>    - Restore backup (remove .bak extension)"
        return 1
    fi

    # Check for undo flag
    if [ "$1" == "-u" ]; then
        if [ -z "$2" ]; then
            echo "Error: No file specified for restore"
            echo "Usage: bak -u <file.bak>"
            return 1
        fi

        # Verify the file exists
        if [ ! -f "$2" ]; then
            echo "Error: File '$2' not found"
            return 1
        fi

        # Verify it's a file, not a directory
        if [ -d "$2" ]; then
            echo "Error: '$2' is a directory, not a file"
            return 1
        fi

        # Verify it has .bak extension
        if [[ ! "$2" =~ \.bak$ ]]; then
            echo "Error: File '$2' does not have a .bak extension"
            return 1
        fi

        # Remove .bak extension
        local original="${2%.bak}"

        # Check if original file already exists
        if [ -f "$original" ]; then
            echo "Error: Target file '$original' already exists"
            echo "Remove it first or rename the backup file"
            return 1
        fi

        mv "$2" "$original"
        echo "Restored: $2 -> $original"
        return 0
    fi

    # Regular backup operation
    # Verify the file exists
    if [ ! -f "$1" ]; then
        echo "Error: File '$1' not found"
        return 1
    fi

    # Verify it's a file, not a directory
    if [ -d "$1" ]; then
        echo "Error: '$1' is a directory, not a file"
        return 1
    fi

    # Check if file already has .bak extension
    if [[ "$1" =~ \.bak$ ]]; then
        echo "Error: File '$1' already has a .bak extension"
        echo "Use 'bak -u $1' to restore it instead"
        return 1
    fi

    # Check if backup already exists
    if [ -f "$1.bak" ]; then
        echo "Error: Backup file '$1.bak' already exists"
        echo "Remove it first or use a different name"
        return 1
    fi

    # Create backup
    mv "$1" "$1.bak"
    echo "Backed up: $1 -> $1.bak"
    return 0
}
