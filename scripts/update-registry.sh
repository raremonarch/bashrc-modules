#!/bin/bash
# Update module version in registry.json

REPO_BASE_URL="https://raw.githubusercontent.com/raremonarch/bashrc-modules/main/modules"

# Always run from the repo root so relative paths (registry.json, modules/) work
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || { echo "Error: could not cd to repo root"; exit 1; }

if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  $0 <module-name> <version>     # Update specific module"
    echo "  $0 --all                        # Update all modules from files to registry"
    echo ""
    echo "Examples:"
    echo "  $0 ssh-host-manager 0.6.0"
    echo "  $0 --all"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: sudo dnf install jq"
    exit 1
fi

# Extract exports from a single file (internal helper)
extract_exports_from_file() {
    local file="$1"

    # Extract alias names (handles: alias name='...' or alias name="...")
    grep -E '^alias [a-zA-Z_][a-zA-Z0-9_-]*=' "$file" 2>/dev/null | sed -E "s/^alias ([a-zA-Z_][a-zA-Z0-9_-]*)=.*/\1/"

    # Note: functions and variables are extracted separately
}

extract_functions_from_file() {
    local file="$1"

    # Extract function names (handles: function name(), function name {, or name())
    grep -E '^(function [a-zA-Z_][a-zA-Z0-9_-]*\s*(\(\)|\{|\()|[a-zA-Z_][a-zA-Z0-9_-]*\s*\(\))' "$file" 2>/dev/null | \
        sed -E 's/^function ([a-zA-Z_][a-zA-Z0-9_-]*).*/\1/; s/^([a-zA-Z_][a-zA-Z0-9_-]*)\s*\(\).*/\1/'
}

extract_variables_from_file() {
    local file="$1"

    # Extract exported variables (handles: export VAR= or VAR= at start of line, excluding local vars)
    grep -E '^(export )?[A-Z_][A-Z0-9_]*=' "$file" 2>/dev/null | sed -E 's/^(export )?([A-Z_][A-Z0-9_]*)=.*/\2/'
}

# Extract exports from a module (main file + any sub-files in matching directory)
extract_exports() {
    local module_file="$1"
    local module_dir="${module_file%.sh}"

    # Collect all files to parse
    local files_to_parse=("$module_file")

    # Check for sub-directory with same name as module
    if [ -d "$module_dir" ]; then
        for subfile in "$module_dir"/*.sh; do
            [ -f "$subfile" ] && files_to_parse+=("$subfile")
        done
    fi

    # Extract from all files and combine
    local aliases="" functions="" variables=""
    for file in "${files_to_parse[@]}"; do
        aliases+=$(extract_exports_from_file "$file")$'\n'
        functions+=$(extract_functions_from_file "$file")$'\n'
        variables+=$(extract_variables_from_file "$file")$'\n'
    done

    # Remove empty lines, filter out internal helpers (starting with _), and sort
    aliases=$(echo "$aliases" | grep -v '^$' | grep -v '^_' | sort -u)
    functions=$(echo "$functions" | grep -v '^$' | grep -v '^_' | sort -u)
    variables=$(echo "$variables" | grep -v '^$' | sort -u)

    # Convert to JSON arrays
    local aliases_json functions_json variables_json
    if [ -n "$aliases" ]; then
        aliases_json=$(echo "$aliases" | jq -R . | jq -s .)
    else
        aliases_json="[]"
    fi

    if [ -n "$functions" ]; then
        functions_json=$(echo "$functions" | jq -R . | jq -s .)
    else
        functions_json="[]"
    fi

    if [ -n "$variables" ]; then
        variables_json=$(echo "$variables" | jq -R . | jq -s .)
    else
        variables_json="[]"
    fi

    # Return as JSON object
    jq -n --argjson aliases "$aliases_json" --argjson functions "$functions_json" --argjson variables "$variables_json" \
        '{aliases: $aliases, functions: $functions, variables: $variables}'
}

# Build the files array for a module that has a sub-directory (e.g. ssh-host-manager/)
# Scans modules/<name>/ for .sh and .md files and returns a JSON array of {path, url} objects.
# Returns "[]" (no files field) if no sub-directory exists.
build_files_array() {
    local module_name="$1"
    local module_dir="modules/${module_name}"

    if [ ! -d "$module_dir" ]; then
        echo "[]"
        return
    fi

    local files_json="[]"
    while IFS= read -r file; do
        local rel_path="${file#modules/}"
        local url="${REPO_BASE_URL}/${rel_path}"
        files_json=$(echo "$files_json" | jq --arg path "$rel_path" --arg url "$url" \
            '. += [{path: $path, url: $url}]')
    done < <(find "$module_dir" -maxdepth 1 \( -name "*.sh" -o -name "*.md" \) | sort)

    echo "$files_json"
}

# Get existing categories from registry for display
get_existing_categories() {
    jq -r '.modules[].category' registry.json | sort -u
}

# Prompt user for module metadata and add to registry
add_new_module() {
    local module_file="$1"
    local module_name=$(basename "$module_file" .sh)

    echo ""
    echo "  New module detected: $module_name"
    read -rp "  Add to registry? [y/N] " add_confirm
    if [[ ! "$add_confirm" =~ ^[Yy]$ ]]; then
        echo "  Skipped."
        return
    fi

    # Extract or prompt for version
    local version=$(grep -E '^# Version:' "$module_file" | head -1 | sed -E 's/^# Version: //')
    if [ -z "$version" ]; then
        read -rp "  No version header found. Enter version (e.g. 0.1.0): " version
        if [ -z "$version" ]; then
            echo "  Error: Version is required. Skipping."
            return
        fi
        # Offer to write it back
        read -rp "  Write '# Version: $version' into the file header? [Y/n] " write_ver
        if [[ ! "$write_ver" =~ ^[Nn]$ ]]; then
            _insert_header_field "$module_file" "Version" "$version"
            echo "  Written to file."
        fi
    fi

    # Extract or prompt for description
    local description=$(grep -E '^# Description:' "$module_file" | head -1 | sed -E 's/^# Description: //')
    if [ -z "$description" ]; then
        read -rp "  No description header found. Enter description: " description
        if [ -z "$description" ]; then
            echo "  Error: Description is required. Skipping."
            return
        fi
        # Offer to write it back
        read -rp "  Write '# Description: $description' into the file header? [Y/n] " write_desc
        if [[ ! "$write_desc" =~ ^[Nn]$ ]]; then
            _insert_header_field "$module_file" "Description" "$description"
            echo "  Written to file."
        fi
    fi

    # Prompt for category
    echo "  Existing categories: $(get_existing_categories | tr '\n' ', ' | sed 's/,$//')"
    read -rp "  Enter category for '$module_name': " category
    if [ -z "$category" ]; then
        echo "  Error: Category is required. Skipping."
        return
    fi

    # Extract exports and sub-directory files
    local exports=$(extract_exports "$module_file")
    local url="${REPO_BASE_URL}/${module_name}.sh"
    local files_json=$(build_files_array "$module_name")

    # Add to registry (include files array only if sub-directory exists)
    if [ "$files_json" != "[]" ]; then
        jq --arg id "$module_name" --arg desc "$description" --arg ver "$version" \
           --arg url "$url" --arg cat "$category" --argjson exports "$exports" \
           --argjson files "$files_json" \
           '.modules += [{id: $id, description: $desc, version: $ver, url: $url, category: $cat, exports: $exports, files: $files}]' \
           registry.json > registry.json.tmp
    else
        jq --arg id "$module_name" --arg desc "$description" --arg ver "$version" \
           --arg url "$url" --arg cat "$category" --argjson exports "$exports" \
           '.modules += [{id: $id, description: $desc, version: $ver, url: $url, category: $cat, exports: $exports}]' \
           registry.json > registry.json.tmp
    fi
    mv registry.json.tmp registry.json

    echo "  ✓ Added $module_name ($version) to registry"
}

# Insert a header field into the module file after the shebang/existing headers
_insert_header_field() {
    local file="$1"
    local field="$2"
    local value="$3"

    # If the file already has header comments (# Module:, # Version:, # Description:),
    # insert after the last one. Otherwise insert after the shebang line.
    local last_header_line=$(grep -n '^# \(Module\|Version\|Description\|BashMod Dependencies\):' "$file" | tail -1 | cut -d: -f1)

    if [ -n "$last_header_line" ]; then
        sed -i "${last_header_line}a\\# ${field}: ${value}" "$file"
    else
        # Insert after shebang (line 1) or at line 2
        local shebang_line=$(head -1 "$file")
        if [[ "$shebang_line" == \#!* ]]; then
            sed -i "1a\\# ${field}: ${value}" "$file"
        else
            sed -i "1i\\# ${field}: ${value}" "$file"
        fi
    fi
}

# Check if a module exists in the registry
module_in_registry() {
    local module_name="$1"
    jq -e --arg name "$module_name" '.modules[] | select(.id == $name)' registry.json > /dev/null 2>&1
}

if [ "$1" = "--all" ]; then
    echo "Updating all module versions and exports in registry..."

    for module_file in modules/*.sh; do
        [ -f "$module_file" ] || continue

        module_name=$(basename "$module_file" .sh)
        version=$(grep -E '^# Version:' "$module_file" | head -1 | sed -E 's/^# Version: //')
        description=$(grep -E '^# Description:' "$module_file" | head -1 | sed -E 's/^# Description: //')

        if module_in_registry "$module_name"; then
            if [ -n "$version" ]; then
                exports=$(extract_exports "$module_file")
                files_json=$(build_files_array "$module_name")
                if [ "$files_json" != "[]" ]; then
                    jq --arg name "$module_name" --arg ver "$version" \
                       --argjson exports "$exports" --argjson files "$files_json" \
                       '(.modules[] | select(.id == $name)) |= (.version = $ver | .exports = $exports | .files = $files)' \
                       registry.json > registry.json.tmp
                else
                    jq --arg name "$module_name" --arg ver "$version" --argjson exports "$exports" \
                        '(.modules[] | select(.id == $name)) |= (.version = $ver | .exports = $exports)' \
                        registry.json > registry.json.tmp
                fi
                mv registry.json.tmp registry.json
                echo "  ✓ $module_name: $version"
            fi
        else
            add_new_module "$module_file"
        fi
    done

    echo ""
    echo "✓ Registry updated!"
    echo ""
    echo "Don't forget to stage registry.json:"
    echo "  git add registry.json"

    # Hint about hook installation
    if [ ! -f ".git/hooks/pre-commit" ]; then
        echo ""
        echo "Tip: Install the pre-commit hook for automatic validation:"
        echo "  ./scripts/install-hooks.sh"
    fi
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

    # Update version in the module file header
    current_version=$(grep -E '^# Version:' "$module_file" | head -1 | sed -E 's/^# Version: //')
    if [ -n "$current_version" ] && [ "$current_version" != "$version" ]; then
        sed -i "s/^# Version: ${current_version}$/# Version: ${version}/" "$module_file"
        echo "✓ Updated module file: $module_name $current_version → $version"
    elif [ -z "$current_version" ]; then
        _insert_header_field "$module_file" "Version" "$version"
        echo "✓ Added version header to module file: $module_name $version"
    fi

    # Check if module exists in registry; if not, offer to add it
    if ! module_in_registry "$module_name"; then
        echo "Module '$module_name' not found in registry."
        add_new_module "$module_file"
    else
        # Extract exports and sub-directory files from module
        exports=$(extract_exports "$module_file")
        files_json=$(build_files_array "$module_name")

        if [ "$files_json" != "[]" ]; then
            jq --arg name "$module_name" --arg ver "$version" \
               --argjson exports "$exports" --argjson files "$files_json" \
               '(.modules[] | select(.id == $name)) |= (.version = $ver | .exports = $exports | .files = $files)' \
               registry.json > registry.json.tmp
        else
            jq --arg name "$module_name" --arg ver "$version" --argjson exports "$exports" \
                '(.modules[] | select(.id == $name)) |= (.version = $ver | .exports = $exports)' \
                registry.json > registry.json.tmp
        fi
        mv registry.json.tmp registry.json

        echo "✓ Updated registry: $module_name → $version"
    fi

    echo ""
    echo "Don't forget to stage updated files:"
    echo "  git add registry.json"
    echo "  git add $module_file"
fi
