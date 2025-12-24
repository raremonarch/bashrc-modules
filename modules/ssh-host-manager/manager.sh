#!/bin/bash
# Core SSH host management with dynamic clone function generation

# Configuration options (can be overridden before sourcing this module)
SSH_HOST_MANAGER_AUTO_ALIAS="${SSH_HOST_MANAGER_AUTO_ALIAS:-true}"           # Auto-use org name as alias for Git hosts
SSH_HOST_MANAGER_AUTO_CLONE_DIR="${SSH_HOST_MANAGER_AUTO_CLONE_DIR:-true}"   # Auto-set clone dir to ~/code/<org>
SSH_HOST_MANAGER_CLONE_DIR_BASE="${SSH_HOST_MANAGER_CLONE_DIR_BASE:-${CODE_BASE_DIR:-$HOME/code}}"  # Base directory for Git clones

# SSH config file location
SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

# Ensure SSH directory and config exist
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Helper function to list available SSH keys
_list_ssh_keys() {
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
    # Return the array via a global variable (bash limitation)
    _SSH_KEYS=("${keys[@]}")
    return $i
}

# Helper function to reset config parsing variables
_reset_config_vars() {
    current_host=""
    current_hostname=""
    current_user=""
    current_key=""
    current_port=""
    current_org=""
    current_clone_dir=""
    current_type="ssh"
}

# Helper function to show help text
_show_help() {
    echo "Usage: ssh-host-add <hostname> [options]"
    echo ""
    echo "Interactively add an SSH host configuration with key management."
    echo ""
    echo "Options:"
    echo "  --host-alias <alias>    Set the host alias (defaults to org for Git hosts)"
    echo "  --user <username>       Set the SSH username"
    echo "  --port <port>           Set the SSH port (default: 22)"
    echo "  --key <path>            Use an existing SSH key at the specified path"
    echo ""
    echo "Configuration:"
    echo "  SSH_HOST_MANAGER_AUTO_ALIAS=${SSH_HOST_MANAGER_AUTO_ALIAS}"
    echo "    Auto-use org name as alias for Git hosts (set to 'false' to prompt)"
    echo "  SSH_HOST_MANAGER_AUTO_CLONE_DIR=${SSH_HOST_MANAGER_AUTO_CLONE_DIR}"
    echo "    Auto-set clone directory (set to 'false' to prompt)"
    echo "  SSH_HOST_MANAGER_CLONE_DIR_BASE=${SSH_HOST_MANAGER_CLONE_DIR_BASE}"
    echo "    Base directory for Git clones"
    echo ""
    echo "Examples:"
    echo "  ssh-host-add macmini.lan"
    echo "  ssh-host-add macmini.lan --host-alias mac --user david --key ~/.ssh/id_ed25519"
    echo "  ssh-host-add github.com --host-alias gh-work"
    echo ""
    echo "To customize behavior, set variables before sourcing this module:"
    echo "  export SSH_HOST_MANAGER_AUTO_ALIAS=false"
    echo "  export SSH_HOST_MANAGER_CLONE_DIR_BASE=~/projects"
}

# Helper function to find matching SSH key for org
_find_matching_key() {
    local org="$1"
    local matching_key=""

    while IFS= read -r pubkey; do
        local privkey="${pubkey%.pub}"
        local keyname=$(basename "$privkey")
        if [ -f "$privkey" ] && [[ "$keyname" =~ (^|[_-])${org}([_-]|$) ]] || [[ "${keyname,,}" == *"${org,,}"* ]]; then
            matching_key="$privkey"
            break
        fi
    done < <(find ~/.ssh -maxdepth 1 -name "*.pub" -type f 2>/dev/null | sort)

    echo "$matching_key"
}

# Helper function to handle SSH key selection
_select_ssh_key() {
    local host_type="$1"
    local org="$2"
    local key_override="$3"
    local key_path=""
    local generate_key=false
    local key_type="ed25519"

    # If key override is provided, use it directly
    if [ -n "$key_override" ]; then
        key_path="${key_override/#\~/$HOME}"
        if [ ! -f "$key_path" ] || [ ! -f "${key_path}.pub" ]; then
            echo "Error: Key file not found: $key_path"
            return 1
        fi
        echo "Using specified key: $(basename "$key_path")"
    # For Git hosts, try to find a matching key based on org/username
    elif [ "$host_type" = "git" ] && [ -n "$org" ]; then
        local matching_key=$(_find_matching_key "$org")

        if [ -n "$matching_key" ]; then
            local keyname=$(basename "$matching_key")
            local keytype=$(ssh-keygen -l -f "${matching_key}.pub" 2>/dev/null | awk '{print $NF}' | tr -d '()')
            echo "Found matching SSH key: $keyname ${keytype:+($keytype)}"
            echo ""
            echo "Options:"
            echo "  [1] Use $keyname (recommended)"
            echo "  [2] Choose another existing key"
            echo "  [3] Generate a new key"
            echo ""
            read -p "Select option [1]: " key_option
            key_option="${key_option:-1}"

            case "$key_option" in
                1)
                    key_path="$matching_key"
                    ;;
                2)
                    echo ""
                    echo "Available SSH keys in ~/.ssh/:"
                    _list_ssh_keys
                    local keys=("${_SSH_KEYS[@]}")
                    echo ""
                    read -p "Select key [1-${#keys[@]}] or enter custom path: " key_choice
                    if [[ "$key_choice" =~ ^[0-9]+$ ]] && [ "$key_choice" -ge 1 ] && [ "$key_choice" -le ${#keys[@]} ]; then
                        key_path="${keys[$((key_choice-1))]}"
                    else
                        key_path="$key_choice"
                    fi
                    ;;
                3)
                    generate_key=true
                    read -p "Key type [ed25519]: " key_type
                    key_type="${key_type:-ed25519}"
                    ;;
                *)
                    echo "Invalid option, using matched key"
                    key_path="$matching_key"
                    ;;
            esac
        fi
    fi

    # Standard key selection flow (when no override or matching key)
    if [ -z "$key_path" ] && [ "$generate_key" = false ]; then
        echo "Available SSH keys in ~/.ssh/:"
        _list_ssh_keys
        local keys=("${_SSH_KEYS[@]}")
        local gen_option=$?
        echo "  [$gen_option] Generate a new key"

        if [ ${#keys[@]} -eq 0 ]; then
            read -p "Select option [$gen_option]: " key_choice
            key_choice="${key_choice:-$gen_option}"
        else
            read -p "Select key [1-$gen_option] or enter custom path: " key_choice
        fi

        if [[ "$key_choice" =~ ^[0-9]+$ ]]; then
            if [ "$key_choice" -eq "$gen_option" ]; then
                generate_key=true
                read -p "Key type [ed25519]: " key_type
                key_type="${key_type:-ed25519}"
            elif [ "$key_choice" -ge 1 ] && [ "$key_choice" -le ${#keys[@]} ]; then
                key_path="${keys[$((key_choice-1))]}"
            else
                echo "Error: Invalid selection"
                return 1
            fi
        else
            key_path="$key_choice"
        fi
    fi

    # Export results via global variables (bash limitation for returning multiple values)
    _SELECTED_KEY_PATH="$key_path"
    _GENERATE_KEY="$generate_key"
    _KEY_TYPE="$key_type"
    return 0
}

# Helper function to copy SSH key to remote host
_copy_ssh_key() {
    local key_path="$1"
    local user="$2"
    local hostname="$3"
    local port="$4"

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
        [[ $REPLY =~ ^[Yy]$ ]]
    else
        echo "✓ Public key copied successfully"
        return 0
    fi
}

# Helper function to generate new SSH key
_generate_ssh_key() {
    local host_alias="$1"
    local key_type="$2"
    local user="$3"
    local hostname="$4"
    local host_type="$5"
    local port="$6"
    local org="$7"

    # Determine key naming based on host type and hostname
    local key_name
    if [ "$host_type" = "git" ]; then
        # For Git hosts that require unique keys per account (GitHub, GitLab, Bitbucket)
        case "$hostname" in
            github.com|gitlab.com|bitbucket.org)
                # Use gh_<org>_<keytype> pattern
                local prefix
                case "$hostname" in
                    github.com) prefix="gh" ;;
                    gitlab.com) prefix="gl" ;;
                    bitbucket.org) prefix="bb" ;;
                esac
                key_name="${prefix}_${org}_${key_type}"
                ;;
            *)
                # Other Git hosts: use alias_keytype pattern
                key_name="${host_alias}_${key_type}"
                ;;
        esac
    else
        # SSH hosts: use alias_keytype pattern
        key_name="${host_alias}_${key_type}"
    fi

    local key_path="$HOME/.ssh/${key_name}"

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
            read -p "Copy public key to remote host? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                _copy_ssh_key "$key_path" "$user" "$hostname" "$port" || return 1
            fi
            echo ""
            echo "Note: Once the SSH config is saved, connect with: ssh ${host_alias}"
        fi
    fi

    echo "$key_path"
}

# Function to add a new SSH host
ssh-host-add() {
    # Initialize variables
    local hostname=""
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
    local alias_override=""
    local user_override=""
    local key_override=""
    local port_override=""

    # Show help if requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _show_help
        return 0
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host-alias)
                alias_override="$2"
                shift 2
                ;;
            --user)
                user_override="$2"
                shift 2
                ;;
            --port)
                port_override="$2"
                shift 2
                ;;
            --key)
                key_override="$2"
                shift 2
                ;;
            *)
                if [ -z "$hostname" ]; then
                    hostname="$1"
                else
                    echo "Error: Unexpected argument '$1'"
                    echo "Use --help for usage information"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Require hostname
    if [ -z "$hostname" ]; then
        echo "Usage: ssh-host-add <hostname> [options]"
        echo "Example: ssh-host-add macmini.lan"
        echo "Use --help for more information"
        return 1
    fi

    # Show example SSH config format only in interactive mode
    if [ -z "$alias_override" ] && [ -z "$user_override" ] && [ -z "$key_override" ]; then
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
    fi

    # Detect if this might be a Git host
    local is_git_host=false
    case "$hostname" in
        github.com|gitlab.com|bitbucket.org|*.github.com|*.gitlab.com)
            is_git_host=true
            ;;
    esac

    # Ask about host type first for non-Git hosts
    if [ "$is_git_host" = true ]; then
        echo ""
        echo "Detected Git host: $hostname"
        host_type="git"
        user="git"

        # For Git hosts, ask for org first to use as default alias
        echo ""
        read -p "Git organization/username: " org
        if [ -z "$org" ]; then
            echo "Error: Organization is required for Git hosts"
            return 1
        fi

        # Use org as alias (or override if provided)
        if [ -n "$alias_override" ]; then
            host_alias="$alias_override"
        elif [ "$SSH_HOST_MANAGER_AUTO_ALIAS" = "true" ]; then
            host_alias="$org"
        else
            read -p "Host alias [$org]: " host_alias
            host_alias="${host_alias:-$org}"
        fi

        # Set clone directory
        if [ "$SSH_HOST_MANAGER_AUTO_CLONE_DIR" = "true" ]; then
            # Auto-set to <base>/<org>
            clone_dir="${SSH_HOST_MANAGER_CLONE_DIR_BASE}/$org"
            # Convert to tilde notation if under $HOME
            clone_dir="${clone_dir/#$HOME/\~}"
        else
            local default_clone_dir="${SSH_HOST_MANAGER_CLONE_DIR_BASE}/$org"
            default_clone_dir="${default_clone_dir/#$HOME/\~}"
            read -p "Clone directory [$default_clone_dir]: " clone_dir
            clone_dir="${clone_dir:-$default_clone_dir}"
        fi
    else
        # Non-Git host: use alias override or prompt
        if [ -n "$alias_override" ]; then
            host_alias="$alias_override"
        else
            read -p "Host alias (short name for 'ssh <alias>'): " host_alias
            if [ -z "$host_alias" ]; then
                echo "Error: Host alias is required"
                return 1
            fi
        fi

        read -p "Is this for Git repositories? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            host_type="git"
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
    fi

    # Prompt based on host type
    if [ "$host_type" != "git" ]; then
        # SSH host prompts
        # Use user override or prompt
        if [ -n "$user_override" ]; then
            user="$user_override"
        else
            read -p "SSH username: " user
            if [ -z "$user" ]; then
                echo "Error: Username is required"
                return 1
            fi
        fi

        # Use port override or prompt
        if [ -n "$port_override" ]; then
            port="$port_override"
        else
            read -p "SSH port [22]: " port
            port="${port:-22}"
        fi
    fi

    # Ask about SSH key
    echo "SSH Key Setup:"

    _select_ssh_key "$host_type" "$org" "$key_override" || return 1
    key_path="$_SELECTED_KEY_PATH"
    generate_key="$_GENERATE_KEY"
    key_type="$_KEY_TYPE"

    # Ask about copying key (SSH hosts only)
    if [ "$host_type" = "ssh" ] && [ "$generate_key" = false ]; then
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
        key_path=$(_generate_ssh_key "$host_alias" "$key_type" "$user" "$hostname" "$host_type" "$port" "$org") || return 1
    else
        # Validate existing key
        key_path="${key_path/#\~/$HOME}"
        if [ ! -f "$key_path" ] || [ ! -f "${key_path}.pub" ]; then
            echo "Error: Key file not found: $key_path"
            return 1
        fi
    fi

    # Copy public key to remote host if requested (SSH hosts only, via CLI flag)
    if [ "$copy_key" = true ]; then
        if [ "$host_type" = "git" ]; then
            echo "Warning: --copy-key is only applicable to SSH hosts, not Git hosts"
            echo "         For Git hosts, manually add the public key to your Git provider"
        else
            echo ""
            _copy_ssh_key "$key_path" "$user" "$hostname" "$port" || return 1
        fi
    fi

    # Convert absolute paths back to tilde notation for config
    local key_path_display="${key_path/#$HOME/\~}"

    # Build SSH config entry
    local config_entry="# Managed by ssh-host-manager"

    if [ "$host_type" = "git" ]; then
        local clone_dir_display="${clone_dir/#$HOME/\~}"
        config_entry="$config_entry (type=git, org=$org, clone_dir=$clone_dir_display)"
    else
        config_entry="$config_entry (type=ssh)"
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
    fi

    echo ""
    echo "✓ SSH host '$host_alias' added successfully"

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
        if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager ]]; then
            # Print accumulated data from previous block if any
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

            in_managed_block=true
            _reset_config_vars

            # Parse metadata from single-line comment format
            if [[ "$line" =~ type=([^,\)]+) ]]; then
                current_type="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ org=([^,\)]+) ]]; then
                current_org="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ clone_dir=([^\)]+) ]]; then
                current_clone_dir="${BASH_REMATCH[1]}"
            fi
            continue
        fi

        if [ "$in_managed_block" = true ]; then
            # Parse Host entry
            if [[ "$line" =~ ^Host\ (.+)$ ]]; then
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
                    _reset_config_vars
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
        skip == 1 {
            # Skip lines until we hit an empty line or new Host/comment
            if (/^$/ || /^Host / || /^# Managed by/) {
                skip=0
                managed=0
                buffer=""

                # If this is the start of a new block, process it
                if (/^# Managed by/) {
                    managed=1
                    buffer=$0 "\n"
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

        /^# Managed by ssh-host-manager/ {
            managed=1
            buffer=$0 "\n"
            next
        }

        managed == 1 {
            buffer = buffer $0 "\n"

            if (/^Host /) {
                if ($2 == host) {
                    # This is the host to remove, skip this entire block
                    skip=1
                    managed=0
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

        { print }
    ' "$SSH_CONFIG" > "$temp_file"

    mv "$temp_file" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
}

