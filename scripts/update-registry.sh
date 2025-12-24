#!/bin/bash
# Update module version in registry.json

if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  $0 <module-name> <version>     # Update specific module"
    echo "  $0 --sync                       # Sync all modules from files to registry"
    echo ""
    echo "Examples:"
    echo "  $0 ssh-host-manager 0.6.0"
    echo "  $0 --sync"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: sudo dnf install jq"
    exit 1
fi

if [ "$1" = "--sync" ]; then
    echo "Syncing all module versions from files to registry..."

    for module_file in modules/*.sh; do
        [ -f "$module_file" ] || continue

        module_name=$(basename "$module_file" .sh)
        version=$(grep -E '^# Version:' "$module_file" | head -1 | sed -E 's/^# Version: //')
        description=$(grep -E '^# Description:' "$module_file" | head -1 | sed -E 's/^# Description: //')

        if [ -n "$version" ]; then
            jq ".modules.\"$module_name\".version = \"$version\"" registry.json > registry.json.tmp
            mv registry.json.tmp registry.json
            echo "  ✓ $module_name: $version"
        fi
    done

    echo "✓ Registry synced!"
    echo ""
    echo "Don't forget to stage registry.json:"
    echo "  git add registry.json"
else
    module_name="$1"
    version="$2"

    if [ -z "$version" ]; then
        echo "Error: Version required"
        echo "Usage: $0 <module-name> <version>"
        exit 1
    fi

    # Check if module file exists
    module_file="modules/${module_name}.sh"
    if [ ! -f "$module_file" ]; then
        echo "Error: Module file not found: $module_file"
        exit 1
    fi

    # Update registry
    jq ".modules.\"$module_name\".version = \"$version\"" registry.json > registry.json.tmp
    mv registry.json.tmp registry.json

    echo "✓ Updated registry: $module_name → $version"
    echo ""
    echo "Don't forget to stage registry.json:"
    echo "  git add registry.json"
fi
