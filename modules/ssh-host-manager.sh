#!/bin/bash
# Module: ssh-host-manager
# Version: 0.3.0
# Description: Centralized SSH host and key management with dynamic clone function generation
# BashMod Dependencies: ssh-agent@0.2.0

# SSH config file location
SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

# Ensure SSH directory and config exist
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Function to add a new SSH host
ssh-host-add() {
    # Show help if requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: ssh-host-add <hostname>"
        echo ""
        echo "Interactively add an SSH host configuration with key management."
        echo "You'll be prompted for all required details."
        echo ""
        echo "Example: ssh-host-add macmini.lan"
        return 0
    fi

    # Require hostname as first argument
    local hostname="$1"
    if [ -z "$hostname" ]; then
        echo "Usage: ssh-host-add <hostname>"
        echo "Example: ssh-host-add macmini.lan"
        return 1
    fi

    # Show example SSH config format
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Example SSH Config Format:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Host myserver"
    echo "      HostName server.example.com"
    echo "      User myusername"
    echo "      Port 22"
    echo "      IdentityFile ~/.ssh/id_ed25519"
    echo "      IdentitiesOnly yes"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Initialize variables
    local host_alias=""
    local user=""
    local org=""
    local clone_dir=""
    local key_path=""
    local generate_key=false
    local key_type="ed25519"
    local host_type="ssh"
    local port="22"
    local copy_key=false

    # Detect if this might be a Git host
    local is_git_host=false
    case "$hostname" in
        github.com|gitlab.com|bitbucket.org|*.github.com|*.gitlab.com)
            is_git_host=true
            ;;
    esac

    # Prompt for host alias
    read -p "Host alias (short name for 'ssh <alias>'): " host_alias
    if [ -z "$host_alias" ]; then
        echo "Error: Host alias is required"
        return 1
    fi

    # Check if host already exists
    if grep -q "^Host $host_alias$" "$SSH_CONFIG" 2>/dev/null; then
        echo "Warning: Host alias '$host_alias' already exists in SSH config"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # Ask about host type
    if [ "$is_git_host" = true ]; then
        echo ""
        echo "Detected Git host: $hostname"
        read -p "Is this for Git repositories? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            host_type="git"
        fi
    else
        echo ""
        read -p "Is this for Git repositories? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            host_type="git"
        fi
    fi

    # Prompt based on host type
    if [ "$host_type" = "git" ]; then
        # Git host prompts
        user="git"
        echo ""
        read -p "Git organization/username: " org
        if [ -z "$org" ]; then
            echo "Error: Organization is required for Git hosts"
            return 1
        fi

        read -p "Clone directory (e.g., ~/code/work): " clone_dir
        if [ -z "$clone_dir" ]; then
            echo "Error: Clone directory is required for Git hosts"
            return 1
        fi
    else
        # SSH host prompts
        echo ""
        read -p "SSH username: " user
        if [ -z "$user" ]; then
            echo "Error: Username is required"
            return 1
        fi

        read -p "SSH port [22]: " port
        port="${port:-22}"
    fi

    # Ask about SSH key
    echo ""
    echo "SSH Key Setup:"
    read -p "Use existing SSH key? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Use existing key - show available keys
        echo ""
        echo "Available SSH keys in ~/.ssh/:"

        # Find all private keys (files with corresponding .pub files)
        local keys=()
        local i=1
        while IFS= read -r pubkey; do
            local privkey="${pubkey%.pub}"
            if [ -f "$privkey" ]; then
                keys+=("$privkey")
                local keyname=$(basename "$privkey")
                local keytype=$(ssh-keygen -l -f "$pubkey" 2>/dev/null | awk '{print $NF}' | tr -d '()')
                echo "  [$i] $keyname ${keytype:+($keytype)}"
                ((i++))
            fi
        done < <(find ~/.ssh -maxdepth 1 -name "*.pub" -type f 2>/dev/null | sort)

        if [ ${#keys[@]} -eq 0 ]; then
            echo "  (no existing key pairs found)"
            echo ""
            read -p "Path to SSH key: " key_path
        else
            echo ""
            read -p "Select key [1-${#keys[@]}] or enter custom path: " key_choice

            if [[ "$key_choice" =~ ^[0-9]+$ ]] && [ "$key_choice" -ge 1 ] && [ "$key_choice" -le ${#keys[@]} ]; then
                # User selected a number
                key_path="${keys[$((key_choice-1))]}"
            else
                # User entered a custom path
                key_path="$key_choice"
            fi
        fi

        # Use default if empty
        key_path="${key_path:-~/.ssh/id_ed25519}"
    else
        # Generate new key
        generate_key=true
        read -p "Key type [ed25519]: " key_type
        key_type="${key_type:-ed25519}"
    fi

    # Ask about copying key (SSH hosts only)
    if [ "$host_type" = "ssh" ] && [ "$generate_key" = false ]; then
        echo ""
        read -p "Copy public key to remote host? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            copy_key=true
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Configuration Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Host alias:  $host_alias"
    echo "  Hostname:    $hostname"
    echo "  Type:        $host_type"
    echo "  User:        $user"
    if [ "$host_type" = "ssh" ]; then
        echo "  Port:        $port"
    else
        echo "  Git org:     $org"
        echo "  Clone dir:   $clone_dir"
    fi
    if [ "$generate_key" = true ]; then
        echo "  Key:         (new $key_type key will be generated)"
    else
        echo "  Key:         $key_path"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "Proceed with this configuration? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Cancelled."
        return 1
    fi
    echo ""

    # Handle overwrite if needed
    if grep -q "^Host $host_alias$" "$SSH_CONFIG" 2>/dev/null; then
        _ssh_host_remove_from_config "$host_alias"
    fi

    # Expand tilde in paths
    if [ -n "$clone_dir" ]; then
        clone_dir="${clone_dir/#\~/$HOME}"
    fi

    # Handle key generation or selection
    if [ "$generate_key" = true ]; then
        # Generate new key
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

            if [ "$host_type" = "git" ]; then
                echo "Add this public key to your ${hostname} account"
            else
                echo "Public key generated for ${hostname}"
                echo ""
                echo "Note: Once the SSH config is saved, connect with: ssh ${host_alias}"
            fi
        fi
    else
        # Use existing key
        key_path="${key_path/#\~/$HOME}"

        if [ ! -f "$key_path" ]; then
            echo "Error: Key file not found: $key_path"
            return 1
        fi

        if [ ! -f "${key_path}.pub" ]; then
            echo "Error: Public key file not found: ${key_path}.pub"
            return 1
        fi
    fi

    # Copy public key to remote host if requested (SSH hosts only)
    if [ "$copy_key" = true ]; then
        if [ "$host_type" = "git" ]; then
            echo "Warning: --copy-key is only applicable to SSH hosts, not Git hosts"
            echo "         For Git hosts, manually add the public key to your Git provider"
        else
            echo ""
            echo "Copying public key to ${user}@${hostname}..."
            if [ "$port" != "22" ]; then
                ssh-copy-id -i "${key_path}.pub" -p "$port" "${user}@${hostname}"
            else
                ssh-copy-id -i "${key_path}.pub" "${user}@${hostname}"
            fi

            if [ $? -ne 0 ]; then
                echo "Error: Failed to copy public key to remote host"
                echo "       You can manually copy it later with:"
                echo "       ssh-copy-id -i ${key_path}.pub ${user}@${hostname}"
                read -p "Continue anyway? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return 1
                fi
            else
                echo "✓ Public key copied successfully"
            fi
        fi
    fi

    # Convert absolute paths back to tilde notation for config
    local key_path_display="${key_path/#$HOME/\~}"

    # Build SSH config entry
    local config_entry="
# Managed by ssh-host-manager
# HostType: $host_type"

    if [ "$host_type" = "git" ]; then
        local clone_dir_display="${clone_dir/#$HOME/\~}"
        config_entry="$config_entry
# GitHubOrg: $org
# CloneDir: $clone_dir_display"
    fi

    config_entry="$config_entry
Host $host_alias
    HostName $hostname
    User $user
    IdentityFile $key_path_display
    IdentitiesOnly yes"

    if [ "$port" != "22" ]; then
        config_entry="$config_entry
    Port $port"
    fi

    # Add to SSH config
    echo "$config_entry" >> "$SSH_CONFIG"

    # Create clone directory if it's a Git host
    if [ "$host_type" = "git" ]; then
        mkdir -p "$clone_dir"
        # Register the dynamic clone function
        _ssh_host_register_clone_function "$host_alias" "$hostname" "$user" "$org" "$clone_dir"
    fi

    echo ""
    echo "✓ SSH host '$host_alias' added successfully"
    echo "  Type: $host_type"
    echo "  Connection: ssh $host_alias"

    if [ "$host_type" = "git" ]; then
        echo "  Clone function: clone-${host_alias}"
        echo "  Usage: clone-${host_alias} <repo-name>"
    fi

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
    echo "  Note: Clone function (if any) will be removed on next shell reload"

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
    local current_port=""
    local current_org=""
    local current_clone_dir=""
    local current_type="ssh"

    while IFS= read -r line; do
        # Check if this is a managed block
        if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager$ ]]; then
            in_managed_block=true
            current_host=""
            current_hostname=""
            current_user=""
            current_key=""
            current_port=""
            current_org=""
            current_clone_dir=""
            current_type="ssh"
            continue
        fi

        if [ "$in_managed_block" = true ]; then
            # Parse metadata from comments
            if [[ "$line" =~ ^#\ HostType:\ (.+)$ ]]; then
                current_type="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^#\ GitHubOrg:\ (.+)$ ]]; then
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
            elif [[ "$line" =~ ^[[:space:]]+Port\ (.+)$ ]]; then
                current_port="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+IdentityFile\ (.+)$ ]]; then
                current_key="${BASH_REMATCH[1]}"
            # Empty line or next Host block - print accumulated data
            elif [[ -z "$line" || "$line" =~ ^Host\ .+ || "$line" =~ ^#\ Managed\ by\ .+ ]]; then
                if [ -n "$current_host" ]; then
                    # Expand tilde for display and checking
                    local key_expanded="${current_key/#\~/$HOME}"

                    # Check if key exists
                    local key_status="✓"
                    if [ ! -f "$key_expanded" ]; then
                        key_status="✗ (missing)"
                    fi

                    echo "Host: $current_host ($current_type)"
                    echo "  Hostname:   $current_hostname"
                    if [ -n "$current_port" ]; then
                        echo "  Port:       $current_port"
                    fi
                    echo "  User:       $current_user"

                    if [ "$current_type" = "git" ]; then
                        echo "  Git Org:    $current_org"
                        echo "  Clone dir:  $current_clone_dir"
                        echo "  Function:   clone-${current_host}"
                    fi

                    echo "  Key:        $current_key $key_status"
                    echo "  Connect:    ssh $current_host"
                    echo ""

                    found_any=true
                fi

                # Reset for next block if we hit a new managed block
                if [[ "$line" =~ ^#\ Managed\ by\ .+ ]]; then
                    current_host=""
                    current_hostname=""
                    current_user=""
                    current_key=""
                    current_port=""
                    current_org=""
                    current_clone_dir=""
                    current_type="ssh"
                else
                    in_managed_block=false
                fi
            fi
        fi
    done < "$SSH_CONFIG"

    # Handle last entry if file doesn't end with blank line
    if [ "$in_managed_block" = true ] && [ -n "$current_host" ]; then
        local key_expanded="${current_key/#\~/$HOME}"

        local key_status="✓"
        if [ ! -f "$key_expanded" ]; then
            key_status="✗ (missing)"
        fi

        echo "Host: $current_host ($current_type)"
        echo "  Hostname:   $current_hostname"
        if [ -n "$current_port" ]; then
            echo "  Port:       $current_port"
        fi
        echo "  User:       $current_user"

        if [ "$current_type" = "git" ]; then
            echo "  Git Org:    $current_org"
            echo "  Clone dir:  $current_clone_dir"
            echo "  Function:   clone-${current_host}"
        fi

        echo "  Key:        $current_key $key_status"
        echo "  Connect:    ssh $current_host"
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
            echo \"         -> git@${alias}:${org}/\${1}.git\"
            echo \"         -> cloned to: ${clone_dir}/\${1}\"
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

# Auto-load clone functions for all managed Git hosts on shell startup
_ssh_host_autoload_clone_functions() {
    local in_managed_block=false
    local current_host=""
    local current_hostname=""
    local current_user=""
    local current_org=""
    local current_clone_dir=""
    local current_type="ssh"

    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager$ ]]; then
            in_managed_block=true
            current_host=""
            current_hostname=""
            current_user=""
            current_org=""
            current_clone_dir=""
            current_type="ssh"
            continue
        fi

        if [ "$in_managed_block" = true ]; then
            if [[ "$line" =~ ^#\ HostType:\ (.+)$ ]]; then
                current_type="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^#\ GitHubOrg:\ (.+)$ ]]; then
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
                # Only register clone function for Git hosts
                if [ "$current_type" = "git" ] && [ -n "$current_host" ] && [ -n "$current_org" ] && [ -n "$current_clone_dir" ]; then
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
                    current_type="ssh"
                else
                    in_managed_block=false
                fi
            fi
        fi
    done < "$SSH_CONFIG"

    # Handle last entry
    if [ "$in_managed_block" = true ] && [ "$current_type" = "git" ] && [ -n "$current_host" ] && [ -n "$current_org" ] && [ -n "$current_clone_dir" ]; then
        local clone_dir_expanded="${current_clone_dir/#\~/$HOME}"
        _ssh_host_register_clone_function "$current_host" "$current_hostname" "$current_user" "$current_org" "$clone_dir_expanded"
    fi
}

# Auto-load clone functions when this module is sourced
_ssh_host_autoload_clone_functions
