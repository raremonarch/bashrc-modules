#!/bin/bash
# SSH key management for Git operations

# Function to load SSH key based on a git URL (before cloning)
ssh_load_key_for_url() {
    local git_url="$1"
    local ssh_host
    local key_file

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

    # Check if get_ssh_key_for_host is available from ssh-agent.sh
    if ! type get_ssh_key_for_host &>/dev/null; then
        echo "Error: get_ssh_key_for_host function not found"
        echo "Please ensure ssh-agent.sh is loaded"
        return 1
    fi

    # Use the shared function from ssh-agent.sh
    key_file=$(get_ssh_key_for_host "$ssh_host")

    if [ -z "$key_file" ]; then
        echo "Could not find SSH key for host: $ssh_host"
        return 1
    fi

    # Check if the key is already loaded
    if is_key_loaded "$key_file"; then
        return 0
    fi

    # Load the specific key
    echo "Loading SSH key for $ssh_host: $(basename "$key_file")"
    ssh-add "$key_file"
}

# Ensure an entry exists in a repo's .gitignore, appending it if missing.
_ensure_gitignored() {
    local repo_dir="$1"
    local entry="$2"
    local gitignore="$repo_dir/.gitignore"
    if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
        echo "$entry" >> "$gitignore"
    fi
}

# Check a freshly cloned repo for known hook installation mechanisms and
# echo the appropriate setup command. Checks in order of specificity.
_suggest_git_hooks() {
    local repo="$1"
    local cmd="" label=""

    if [ -d "$repo/scripts/hooks" ]; then
        cmd="git config core.hooksPath scripts/hooks"
        label="scripts/hooks"
    elif [ -d "$repo/.githooks" ]; then
        cmd="git config core.hooksPath .githooks"
        label=".githooks"
    elif [ -d "$repo/.git-hooks" ]; then
        cmd="git config core.hooksPath .git-hooks"
        label=".git-hooks"
    elif [ -f "$repo/.pre-commit-config.yaml" ]; then
        cmd="pre-commit install"
        label="pre-commit"
    elif [ -f "$repo/lefthook.yml" ] || [ -f "$repo/lefthook.toml" ]; then
        cmd="lefthook install"
        label="lefthook"
    elif [ -d "$repo/.husky" ]; then
        cmd="npm run prepare"
        label="husky"
    fi

    if [ -n "$cmd" ]; then
        local full_cmd
        if [ "$repo" = "." ]; then
            full_cmd="$cmd"
        else
            full_cmd="cd $repo && $cmd"
        fi
        echo ""
        echo "  ⚙ Git hooks detected ($label)."
        printf "     Install now? (%s) [Y/n] " "$cmd"
        read -r reply
        reply="${reply:-y}"
        if [[ "$reply" =~ ^[Yy] ]]; then
            local tool="${cmd%% *}"
            if ! command -v "$tool" &>/dev/null; then
                echo ""
                echo "  ✗ '$tool' is not installed — git hooks were not set up."
                case "$tool" in
                    pre-commit)
                        echo "     Install pre-commit:  pipx install pre-commit"
                        echo "                      or: pip install pre-commit"
                        ;;
                    lefthook)
                        echo "     Install lefthook:    brew install lefthook"
                        echo "                      or: go install github.com/evilmartians/lefthook@latest"
                        ;;
                    *)
                        echo "     Please install '$tool' and then run: $full_cmd"
                        ;;
                esac
                echo "     Once installed, set up hooks with: $full_cmd"
            else
                (cd "$repo" && eval "$cmd")
            fi
        else
            echo "     Skipped. To install later: $full_cmd"
        fi
    fi
}

function clone-repo () {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: clone-repo <owner> <repo-name>"
        echo "Examples:"
        echo "  clone-repo raremonarch bashmod"
        echo "    -> git@raremonarch:raremonarch/bashmod.git (uses SSH host alias)"
        echo "    -> ~/code/raremonarch/bashmod"
        echo ""
        echo "  clone-repo EBSCOIS platform.shared.bookjacket-image-resolver"
        echo "    -> git@ebscois:EBSCOIS/platform.shared.bookjacket-image-resolver.git (uses SSH host alias)"
        echo "    -> ~/code/ebscois/platform.shared.bookjacket-image-resolver"
        return 1
    fi

    local owner="$1"
    local repo_name="$2"
    local ssh_host=$(echo "$owner" | tr '[:upper:]' '[:lower:]')

    # Check if there's a configured SSH host for this owner with a clone_dir
    local clone_dir=""
    local has_ssh_host=false
    if grep -q "^Host $ssh_host$" "$HOME/.ssh/config" 2>/dev/null; then
        has_ssh_host=true
        # Look for clone_dir in the managed comment above this host
        local in_block=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^#\ Managed\ by\ ssh-host-manager.*org=${ssh_host} ]]; then
                # Extract clone_dir from comment
                if [[ "$line" =~ clone_dir=([^\)]+) ]]; then
                    clone_dir="${BASH_REMATCH[1]}"
                    clone_dir="${clone_dir/#\~/$HOME}"  # Expand tilde
                fi
            elif [[ "$line" =~ ^Host\ $ssh_host$ ]]; then
                break
            fi
        done < "$HOME/.ssh/config"
    fi

    # Use SSH host alias if configured, otherwise use github.com
    local git_url
    if [ "$has_ssh_host" = true ]; then
        git_url="git@${ssh_host}:${owner}/${repo_name}.git"
    else
        git_url="git@github.com:${owner}/${repo_name}.git"
    fi

    # Determine clone path
    local clone_path
    if [ -n "$clone_dir" ]; then
        clone_path="${clone_dir}/${repo_name}"
    else
        clone_path="${BASHRCMODS_CODE_BASE_DIR}/${ssh_host}/${repo_name}"
    fi

    echo "Cloning ${owner}/${repo_name}..."
    echo "  URL: $git_url"
    echo "  Path: $clone_path"

    if ssh_load_key_for_url "$git_url" && command git clone "$git_url" "$clone_path"; then
        local default_branch
        default_branch=$(git -C "$clone_path" symbolic-ref --short HEAD 2>/dev/null || echo "main")
        printf "%s\n%s\n" "$git_url" "$default_branch" > "$clone_path/.gitremote"
        _ensure_gitignored "$clone_path" ".gitremote"
        _suggest_git_hooks "$clone_path"
    fi
}

function git-setup() {
    local target="${1:-.}"
    target="${target%/}"

    if [ -d "$target/.git" ]; then
        echo "Error: '$target' is already a git repository"
        return 1
    fi

    local remote_url default_branch
    if [ -f "$target/.gitremote" ]; then
        remote_url=$(sed -n '1p' "$target/.gitremote")
        default_branch=$(sed -n '2p' "$target/.gitremote")
        if [ -z "$remote_url" ]; then
            echo "Error: .gitremote file is empty or malformed"
            return 1
        fi
    else
        echo "No .gitremote file found in '$target'."
        echo ""
        local host_alias owner repo_name
        printf "  Host alias (e.g. raremonarch): "
        read -r host_alias
        [ -z "$host_alias" ] && { echo "Error: host alias is required"; return 1; }
        printf "  Repo owner (e.g. raremonarch): "
        read -r owner
        [ -z "$owner" ] && { echo "Error: repo owner is required"; return 1; }
        local default_repo_name
        default_repo_name=$(basename "$target")
        printf "  Repo name [%s]: " "$default_repo_name"
        read -r repo_name
        repo_name="${repo_name:-$default_repo_name}"
        remote_url="git@${host_alias}:${owner}/${repo_name}.git"
        echo ""
    fi

    [ -z "$default_branch" ] && default_branch="main"

    local target_label
    [ "$target" = "." ] && target_label="current directory" || target_label="'$target'"
    echo "Setting up git repository in $target_label..."
    echo "  Remote: $remote_url"
    echo "  Branch: $default_branch"

    if type ssh_load_key_for_url &>/dev/null; then
        ssh_load_key_for_url "$remote_url" 2>/dev/null
    fi

    git -C "$target" init || return 1
    git -C "$target" remote add origin "$remote_url" || return 1
    git -C "$target" fetch origin || return 1
    git -C "$target" symbolic-ref HEAD "refs/heads/$default_branch"
    git -C "$target" update-ref "refs/heads/$default_branch" "refs/remotes/origin/$default_branch"
    git -C "$target" branch --set-upstream-to="origin/$default_branch" "$default_branch"
    git -C "$target" reset
    local stashed=false
    if ! git -C "$target" diff --quiet; then
        git -C "$target" stash push -m "git-setup: preserve local changes"
        stashed=true
    fi
    git -C "$target" reset --hard
    if $stashed; then
        git -C "$target" stash pop
    fi

    printf "%s\n%s\n" "$remote_url" "$default_branch" > "$target/.gitremote"
    _ensure_gitignored "$target" ".gitremote"

    if type _suggest_git_hooks &>/dev/null; then
        _suggest_git_hooks "$target"
    fi

    echo ""
    echo "Done. Run 'git status' to see any uncommitted changes."
}