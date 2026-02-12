#!/bin/bash
# Install git hooks from scripts/hooks/ into .git/hooks/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SOURCE="$SCRIPT_DIR/hooks"
HOOKS_TARGET="$REPO_DIR/.git/hooks"

if [ ! -d "$HOOKS_SOURCE" ]; then
    echo "Error: hooks source directory not found: $HOOKS_SOURCE"
    exit 1
fi

if [ ! -d "$HOOKS_TARGET" ]; then
    echo "Error: .git/hooks directory not found. Is this a git repository?"
    exit 1
fi

for hook in "$HOOKS_SOURCE"/*; do
    [ -f "$hook" ] || continue
    hook_name=$(basename "$hook")

    # Skip non-hook files (hooks are extensionless)
    [[ "$hook_name" == *.* ]] && continue
    target="$HOOKS_TARGET/$hook_name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "  ⚠ $hook_name: already exists (not a symlink), skipping"
        continue
    fi

    ln -sf "$hook" "$target"
    echo "  ✓ $hook_name: installed"
done

echo ""
echo "Done! Hooks are symlinked from scripts/hooks/ → .git/hooks/"
