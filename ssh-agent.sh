# SSH Agent Management
# Ensures SSH agent is running and available for the session
# Keys are loaded on-demand when first needed

# Source the SSH agent environment if it exists
if [ -f "$HOME/.ssh/ssh-agent.env" ]; then
    source "$HOME/.ssh/ssh-agent.env" > /dev/null
fi

# Ensure SSH agent is running (but don't load keys yet)
if ! [ -n "$SSH_AUTH_SOCK" ] || ! [ -n "$SSH_AGENT_PID" ] || ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
    # Start SSH agent silently
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$HOME/.ssh/ssh-agent.env"
    echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$HOME/.ssh/ssh-agent.env"
    chmod 600 "$HOME/.ssh/ssh-agent.env"
fi

# Function to get the SSH key needed for current git repository
get_git_ssh_key() {
    local remote_url
    local ssh_host
    local identity_file
    
    # Get the current git remote URL
    remote_url=$(git remote get-url origin 2>/dev/null) || return 1
    
    # Extract hostname from different URL formats
    case "$remote_url" in
        git@*:*|ssh://git@*)
            # Extract hostname from git@hostname:repo or ssh://git@hostname/repo
            ssh_host=$(echo "$remote_url" | sed -E 's|^(git@\|ssh://git@)([^:/]+).*|\2|')
            ;;
        https://*)
            # Extract hostname from https://hostname/repo
            ssh_host=$(echo "$remote_url" | sed -E 's|^https://([^/]+).*|\1|')
            ;;
        *)
            return 1
            ;;
    esac
    
    # Map common hostnames to SSH config hosts
    case "$ssh_host" in
        github.com)
            # Determine which GitHub account based on repo owner
            local repo_owner=$(echo "$remote_url" | sed -E 's|.*[:/]([^/]+)/[^/]+\.git.*|\1|')
            case "$repo_owner" in
                daevski)
                    ssh_host="daev"
                    ;;
                *)
                    # Default to work account for other repos
                    ssh_host="eis"
                    ;;
            esac
            ;;
    esac
    
    # Look up the identity file for this host in SSH config
    identity_file=$(ssh -G "$ssh_host" 2>/dev/null | grep -E '^identityfile ' | head -1 | awk '{print $2}')
    
    # Expand tilde to home directory
    identity_file="${identity_file/#\~/$HOME}"
    
    if [ -f "$identity_file" ]; then
        echo "$identity_file"
        return 0
    fi
    
    return 1
}

# Function to check if a specific SSH key is loaded
is_key_loaded() {
    local key_file="$1"
    local key_fingerprint

    [ -f "$key_file" ] || return 1

    key_fingerprint=$(ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $2}')
    [ -n "$key_fingerprint" ] && ssh-add -l 2>/dev/null | grep -q "$key_fingerprint"
}

# Function to ensure the right SSH key is loaded for git operations
ssh_load_git_key() {
    local key_file

    # Get the SSH key needed for this git repository
    key_file=$(get_git_ssh_key)

    if [ -z "$key_file" ]; then
        echo "Could not determine SSH key for this repository"
        return 1
    fi

    # Check if the key is already loaded
    if is_key_loaded "$key_file"; then
        return 0
    fi

    # Load the specific key
    echo "Loading SSH key: $(basename "$key_file")"
    ssh-add "$key_file"
}

# Override git command to auto-load SSH keys for remote operations
git() {
    case "$1" in
        push|pull|fetch)
            # Only try to load key if we're in a git repo
            if git rev-parse --git-dir &>/dev/null; then
                ssh_load_git_key || true  # Continue even if key loading fails
            fi
            command git "$@"
            ;;
        *)
            command git "$@"
            ;;
    esac
}