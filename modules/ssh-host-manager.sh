#!/bin/bash
# Module: ssh-host-manager
# Version: 0.1.0
# Description: Centralized SSH host and key management with dynamic clone function generation
# Dependencies: ssh-agent

# SSH config file location
SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

# Ensure SSH directory and config exist
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Function to add a new SSH host
ssh-host-add() {
    local host_alias=""
    local hostname=""
    local user="git"
    local org=""
    local clone_dir=""
    local key_path=""
    local generate_key=false
    local key_type="ed25519"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host-alias)
                host_alias="$2"
                shift 2
                ;;
            --hostname)
                hostname="$2"
                shift 2
                ;;
            --user)
                user="$2"
                shift 2
                ;;
            --org)
                org="$2"
                shift 2
                ;;
            --clone-dir)
                clone_dir="$2"
                shift 2
                ;;
            --key-path)
                key_path="$2"
                shift 2
                ;;
            --generate-key)
                generate_key=true
                shift
                ;;
            --key-type)
                key_type="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: ssh-host-add [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --host-alias ALIAS    SSH host alias (required)"
                echo "  --hostname HOST       Actual hostname (required)"
                echo "  --user USER           SSH user (default: git)"
                echo "  --org ORG             Organization/user on the host (required)"
                echo "  --clone-dir DIR       Base directory for clones (required)"
                echo "  --key-path PATH       Path to SSH key (optional, will be generated if not provided)"
                echo "  --generate-key        Generate a new SSH key"
                echo "  --key-type TYPE       Key type for generation (default: ed25519)"
                echo ""
                echo "Example:"
                echo "  ssh-host-add --host-alias work --hostname github.com --user git \\"
                echo "               --org MyCompany --clone-dir ~/dev/work --generate-key"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$host_alias" ] || [ -z "$hostname" ] || [ -z "$org" ] || [ -z "$clone_dir" ]; then
        echo "Error: Missing required arguments"
        echo "Required: --host-alias, --hostname, --org, --clone-dir"
        echo "Use --help for usage information"
        return 1
    fi

    # Expand tilde in paths
    clone_dir="${clone_dir/#\~/$HOME}"

    # Generate key if requested or no key path provided
    if [ -z "$key_path" ] || [ "$generate_key" = true ]; then
        key_path="$HOME/.ssh/${host_alias}_${key_type}"

        if [ -f "$key_path" ]; then
            echo "Key already exists at: $key_path"
            read -p "Use existing key? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
                return 1
            fi
        else
            echo "Generating new SSH key: $key_path"
            ssh-keygen -t "$key_type" -f "$key_path" -C "${user}@${hostname} (${host_alias})"

            if [ $? -ne 0 ]; then
                echo "Error: Failed to generate SSH key"
                return 1
            fi

            echo ""
            echo "=== Public Key ==="
            cat "${key_path}.pub"
            echo "=================="
            echo ""
            echo "Add this public key to your ${hostname} account"
        fi
    else
        # Expand tilde in provided key path
        key_path="${key_path/#\~/$HOME}"

        if [ ! -f "$key_path" ]; then
            echo "Error: Key file not found: $key_path"
            return 1
        fi
    fi

    # Check if host already exists
    if grep -q "^Host $host_alias$" "$SSH_CONFIG" 2>/dev/null; then
        echo "Warning: Host alias '$host_alias' already exists in SSH config"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        # Remove old entry
        _ssh_host_remove_from_config "$host_alias"
    fi

    # Convert absolute paths back to tilde notation for config
    local key_path_display="${key_path/#$HOME/\~}"
    local clone_dir_display="${clone_dir/#$HOME/\~}"

    # Add to SSH config with metadata in comments
    cat >> "$SSH_CONFIG" << EOF

# Managed by ssh-host-manager
# GitHubOrg: $org
# CloneDir: $clone_dir_display
Host $host_alias
    HostName $hostname
    User $user
    IdentityFile $key_path_display
    IdentitiesOnly yes
EOF

    # Create clone directory if it doesn't exist
    mkdir -p "$clone_dir"

    # Register the dynamic clone function
    _ssh_host_register_clone_function "$host_alias" "$hostname" "$user" "$org" "$clone_dir"

    echo ""
    echo "✓ SSH host '$host_alias' added successfully"
    echo "  Clone function: clone-${host_alias}"
    echo "  Usage: clone-${host_alias} <repo-name>"

    return 0
}

# Function to remove an SSH host
ssh-host-remove() {
    local host_alias="$1"

    if [ -z "$host_alias" ]; then
        echo "Usage: ssh-host-remove <host-alias>"
        return 1
    fi

    # Check if host exists
    if ! grep -q "^Host $host_alias$" "$SSH_CONFIG" 2>/dev/null; then
        echo "Error: Host alias '$host_alias' not found in SSH config"
        return 1
    fi

    # Check if managed by ssh-host-manager
    if ! _ssh_host_is_managed "$host_alias"; then
        echo "Warning: Host '$host_alias' is not managed by ssh-host-manager"
        read -p "Remove anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # Remove from SSH config
    _ssh_host_remove_from_config "$host_alias"

    echo "✓ SSH host '$host_alias' removed from SSH config"
    echo "  Note: Clone function will be removed on next shell reload"

    return 0
}

# Function to list all managed SSH hosts
ssh-host-list() {
    local found_any=false

    echo "Configured SSH Hosts (managed by ssh-host-manager):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Parse SSH config for managed hosts
    local in_managed_block=false
    local current_host=""
    local current_hostname=""
    local current_user=""
    local current_key=""
    local current_org=""
    local current_clone_dir=""

    while IFS= read -r line; do
        # Check if this is a managed block
        if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager$ ]]; then
            in_managed_block=true
            current_host=""
            current_hostname=""
            current_user=""
            current_key=""
            current_org=""
            current_clone_dir=""
            continue
        fi

        if [ "$in_managed_block" = true ]; then
            # Parse metadata from comments
            if [[ "$line" =~ ^#\ GitHubOrg:\ (.+)$ ]]; then
                current_org="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^#\ CloneDir:\ (.+)$ ]]; then
                current_clone_dir="${BASH_REMATCH[1]}"
            # Parse Host entry
            elif [[ "$line" =~ ^Host\ (.+)$ ]]; then
                current_host="${BASH_REMATCH[1]}"
            # Parse config values
            elif [[ "$line" =~ ^[[:space:]]+HostName\ (.+)$ ]]; then
                current_hostname="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+User\ (.+)$ ]]; then
                current_user="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+IdentityFile\ (.+)$ ]]; then
                current_key="${BASH_REMATCH[1]}"
            # Empty line or next Host block - print accumulated data
            elif [[ -z "$line" || "$line" =~ ^Host\ .+ || "$line" =~ ^#\ Managed\ by\ .+ ]]; then
                if [ -n "$current_host" ]; then
                    # Expand tilde for display and checking
                    local key_expanded="${current_key/#\~/$HOME}"
                    local clone_dir_expanded="${current_clone_dir/#\~/$HOME}"

                    # Check if key exists
                    local key_status="✓"
                    if [ ! -f "$key_expanded" ]; then
                        key_status="✗ (missing)"
                    fi

                    echo "Host: $current_host"
                    echo "  Hostname:   $current_hostname"
                    echo "  User:       $current_user"
                    echo "  GitHub Org: $current_org"
                    echo "  Clone dir:  $current_clone_dir"
                    echo "  Key:        $current_key $key_status"
                    echo "  Function:   clone-${current_host}"
                    echo ""

                    found_any=true
                fi

                # Reset for next block if we hit a new managed block
                if [[ "$line" =~ ^#\ Managed\ by\ .+ ]]; then
                    current_host=""
                    current_hostname=""
                    current_user=""
                    current_key=""
                    current_org=""
                    current_clone_dir=""
                else
                    in_managed_block=false
                fi
            fi
        fi
    done < "$SSH_CONFIG"

    # Handle last entry if file doesn't end with blank line
    if [ "$in_managed_block" = true ] && [ -n "$current_host" ]; then
        local key_expanded="${current_key/#\~/$HOME}"
        local clone_dir_expanded="${current_clone_dir/#\~/$HOME}"

        local key_status="✓"
        if [ ! -f "$key_expanded" ]; then
            key_status="✗ (missing)"
        fi

        echo "Host: $current_host"
        echo "  Hostname:   $current_hostname"
        echo "  User:       $current_user"
        echo "  GitHub Org: $current_org"
        echo "  Clone dir:  $current_clone_dir"
        echo "  Key:        $current_key $key_status"
        echo "  Function:   clone-${current_host}"
        echo ""

        found_any=true
    fi

    if [ "$found_any" = false ]; then
        echo "No managed SSH hosts found"
        echo ""
        echo "Use 'ssh-host-add --help' to add a new host"
    fi
}

# Internal function to check if a host is managed by ssh-host-manager
_ssh_host_is_managed() {
    local host_alias="$1"

    # Look for the host and check if it's preceded by the managed marker
    awk -v host="$host_alias" '
        /^# Managed by ssh-host-manager$/ { managed=1; next }
        /^Host / {
            if ($2 == host && managed == 1) {
                exit 0
            }
            managed=0
        }
        /^$/ { managed=0 }
    ' "$SSH_CONFIG"

    return $?
}

# Internal function to remove host from SSH config
_ssh_host_remove_from_config() {
    local host_alias="$1"
    local temp_file=$(mktemp)

    # Use awk to remove the managed block for this host
    awk -v host="$host_alias" '
        /^# Managed by ssh-host-manager$/ {
            managed=1
            buffer="# Managed by ssh-host-manager\n"
            next
        }

        managed == 1 {
            buffer = buffer $0 "\n"

            if (/^Host /) {
                if ($2 == host) {
                    # This is the host to remove, skip this entire block
                    skip=1
                    buffer=""
                } else {
                    # Different host, print the buffer
                    printf "%s", buffer
                    buffer=""
                    managed=0
                    skip=0
                }
                next
            }
        }

        skip == 1 {
            # Skip lines until we hit an empty line or new Host/comment
            if (/^$/ || /^Host / || /^# Managed by/) {
                skip=0
                managed=0
                buffer=""

                # If this is the start of a new block, process it
                if (/^# Managed by/) {
                    managed=1
                    buffer="# Managed by ssh-host-manager\n"
                    next
                } else if (/^Host /) {
                    print
                    next
                } else {
                    # Empty line
                    next
                }
            }
            next
        }

        { print }
    ' "$SSH_CONFIG" > "$temp_file"

    mv "$temp_file" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
}

# Internal function to register a dynamic clone function
_ssh_host_register_clone_function() {
    local alias="$1"
    local hostname="$2"
    local user="$3"
    local org="$4"
    local clone_dir="$5"

    # Create the function dynamically
    eval "
    function clone-${alias}() {
        if [ -z \"\${1}\" ]; then
            echo \"Usage: clone-${alias} <repo-name>\"
            echo \"Example: clone-${alias} my-project\"
            echo \"         -> git@${alias}:${org}/my-project.git\"
            echo \"         -> cloned to: ${clone_dir}/my-project\"
        else
            local git_url=\"git@${alias}:${org}/\${1}.git\"

            # Load the SSH key if ssh_load_key_for_url is available
            if type ssh_load_key_for_url &>/dev/null; then
                ssh_load_key_for_url \"\$git_url\" && git clone \"\$git_url\" \"${clone_dir}/\${1}\"
            else
                git clone \"\$git_url\" \"${clone_dir}/\${1}\"
            fi
        fi
    }
    "
}

# Auto-load clone functions for all managed hosts on shell startup
_ssh_host_autoload_clone_functions() {
    local in_managed_block=false
    local current_host=""
    local current_hostname=""
    local current_user=""
    local current_org=""
    local current_clone_dir=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager$ ]]; then
            in_managed_block=true
            current_host=""
            current_hostname=""
            current_user=""
            current_org=""
            current_clone_dir=""
            continue
        fi

        if [ "$in_managed_block" = true ]; then
            if [[ "$line" =~ ^#\ GitHubOrg:\ (.+)$ ]]; then
                current_org="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^#\ CloneDir:\ (.+)$ ]]; then
                current_clone_dir="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^Host\ (.+)$ ]]; then
                current_host="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+HostName\ (.+)$ ]]; then
                current_hostname="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+User\ (.+)$ ]]; then
                current_user="${BASH_REMATCH[1]}"
            elif [[ -z "$line" || "$line" =~ ^Host\ .+ || "$line" =~ ^#\ Managed\ by\ .+ ]]; then
                if [ -n "$current_host" ] && [ -n "$current_org" ] && [ -n "$current_clone_dir" ]; then
                    # Expand tilde in clone_dir
                    local clone_dir_expanded="${current_clone_dir/#\~/$HOME}"
                    _ssh_host_register_clone_function "$current_host" "$current_hostname" "$current_user" "$current_org" "$clone_dir_expanded"
                fi

                if [[ "$line" =~ ^#\ Managed\ by\ .+ ]]; then
                    current_host=""
                    current_hostname=""
                    current_user=""
                    current_org=""
                    current_clone_dir=""
                else
                    in_managed_block=false
                fi
            fi
        fi
    done < "$SSH_CONFIG"

    # Handle last entry
    if [ "$in_managed_block" = true ] && [ -n "$current_host" ] && [ -n "$current_org" ] && [ -n "$current_clone_dir" ]; then
        local clone_dir_expanded="${current_clone_dir/#\~/$HOME}"
        _ssh_host_register_clone_function "$current_host" "$current_hostname" "$current_user" "$current_org" "$clone_dir_expanded"
    fi
}

# Auto-load clone functions when this module is sourced
_ssh_host_autoload_clone_functions
