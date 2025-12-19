#!/bin/bash
# ~/.bashrc.d/git.sh

alias gitaddcommit='git add -A . && git commit -m '

# Function to load SSH key based on a git URL (before cloning)
ssh_load_key_for_url() {
    local git_url="$1"
    local ssh_host
    local identity_file

    if [ -z "$git_url" ]; then
        echo "No Git URL provided"
        return 1
    fi

    # Extract SSH host from git URL
    case "$git_url" in
        git@*:*)
            # Extract the SSH host from git@host:repo format
            ssh_host=$(echo "$git_url" | sed -E 's|^git@([^:]+):.*|\1|')
            ;;
        ssh://git@*)
            # Extract from ssh://git@host/repo format
            ssh_host=$(echo "$git_url" | sed -E 's|^ssh://git@([^:/]+).*|\1|')
            ;;
        *)
            echo "Not an SSH Git URL: $git_url"
            return 1
            ;;
    esac

    # Look up the identity file for this host in SSH config
    identity_file=$(ssh -G "$ssh_host" 2>/dev/null | grep -E '^identityfile ' | head -1 | awk '{print $2}')

    # Expand tilde to home directory
    identity_file="${identity_file/#\~/$HOME}"

    if [ ! -f "$identity_file" ]; then
        echo "Could not find identity file for host: $ssh_host"
        return 1
    fi

    # Check if the key is already loaded
    if ! type is_key_loaded &>/dev/null; then
        echo "Error: is_key_loaded function not found"
        echo "Please ensure ~/.bashrc.d/ssh-agent.sh is loaded"
        return 1
    fi

    if is_key_loaded "$identity_file"; then
        return 0
    fi

    # Load the specific key
    echo "Loading SSH key for $ssh_host: $(basename "$identity_file")"
    ssh-add "$identity_file"
}

function clone-eis () {
    if [ -z ${1} ]; then
        echo "Usage: clone-eis <repo-name>"
    echo "Example: clone-eis platform.shared.bookjacket-image-resolver"
    echo "         -> git@eis:EBSCOIS/platform.shared.bookjacket-image-resolver.git"
    else
    local git_url="git@eis:EBSCOIS/${1}.git"
    ssh_load_key_for_url "$git_url" && git clone "$git_url" ~/development/eis/${1}
    fi
}

function clone-daevski () {
    if [ -z ${1} ]; then
        echo "Usage: clone-daevski <repo-name>"
    echo "Example: clone-daevski my-personal-project"
    echo "         -> git@daevski:daevski/my-personal-project.git"
    else
    local git_url="git@daevski:daevski/${1}.git"
    ssh_load_key_for_url "$git_url" && git clone "$git_url" ~/development/daevski/${1}
    fi
}

function git-del-branch() {
    branch="$1"
    git checkout main
    git branch -D "$branch" && git push origin --delete "$branch" && git fetch --prune
}