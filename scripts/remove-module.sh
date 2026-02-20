#!/bin/bash
# Remove a module from the registry and filesystem

# Always run from the repo root so relative paths (registry.json, modules/) work
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || { echo "Error: could not cd to repo root"; exit 1; }

if [ $# -eq 0 ]; then
    echo "Usage: $0 <module-name>"
    echo ""
    echo "Examples:"
    echo "  $0 ssh-host-manager"
    echo "  $0 old-module"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: sudo dnf install jq"
    exit 1
fi

module_name="$1"

# Check if module exists in registry
if ! jq -e --arg name "$module_name" '.modules[] | select(.id == $name)' registry.json > /dev/null 2>&1; then
    echo "Error: Module '$module_name' not found in registry"
    exit 1
fi

# Confirm deletion
echo "This will remove:"
echo "  - Module entry from registry.json"
echo "  - File: modules/${module_name}.sh (if exists)"
echo "  - Directory: modules/${module_name}/ (if exists)"
echo ""
read -rp "Are you sure you want to remove '$module_name'? [y/N] " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove from registry.json
jq --arg name "$module_name" '.modules |= map(select(.id != $name))' \
    registry.json > registry.json.tmp
mv registry.json.tmp registry.json
echo "  ✓ Removed from registry.json"

# Remove module file if it exists
module_file="modules/${module_name}.sh"
if [ -f "$module_file" ]; then
    # Use git rm if file is tracked
    if git ls-files --error-unmatch "$module_file" > /dev/null 2>&1; then
        git rm "$module_file"
        echo "  ✓ Removed and staged: $module_file"
    else
        rm "$module_file"
        echo "  ✓ Removed: $module_file"
    fi
fi

# Remove module directory if it exists
module_dir="modules/${module_name}"
if [ -d "$module_dir" ]; then
    # Use git rm if directory is tracked
    if git ls-files --error-unmatch "$module_dir" > /dev/null 2>&1; then
        git rm -r "$module_dir"
        echo "  ✓ Removed and staged: $module_dir/"
    else
        rm -rf "$module_dir"
        echo "  ✓ Removed: $module_dir/"
    fi
fi

echo ""
echo "✓ Module '$module_name' removed successfully!"
echo ""
echo "Don't forget to stage registry.json:"
echo "  git add registry.json"
