# SSH Host Manager Components

This directory contains the component modules for the ssh-host-manager suite.

## Components

- **ssh-agent.sh** - SSH agent management with automatic key loading
- **git-ssh.sh** - SSH key management for Git operations
- **git-clone.sh** - Git repository cloning shortcuts
- **host-manager.sh** - Core SSH host configuration management

## Loading Order

Components are loaded in this specific order by the main module:
1. ssh-agent.sh (must be first - provides core SSH functionality)
2. git-ssh.sh (depends on ssh-agent.sh)
3. git-clone.sh (depends on git-ssh.sh)
4. host-manager.sh (uses functions from all previous components)

## Configuration

The main `ssh-host-manager.sh` module sets the global `CODE_BASE_DIR` variable, which is used as the default base directory for Git clones. To customize this value, set it before sourcing the module:

```bash
# In your ~/.bashrc or before sourcing modules:
export CODE_BASE_DIR="$HOME/projects"
```

If not set, it defaults to `$HOME/code`.

## Note

These component files are not meant to be sourced individually. They are automatically loaded by the main `ssh-host-manager.sh` module.
