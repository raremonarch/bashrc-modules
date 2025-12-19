# bashrc-modules

Personal collection of modular bash configuration files for managing development workflows, system utilities, and tool configurations.

## Usage

These modules are designed to be used with [bash-mods](https://github.com/user/bash-mods), a TUI package manager for bash configurations.

### Install bash-mods

```bash
pipx install git+https://github.com/user/bash-mods.git
```

### Configure

Create `~/.config/bash-mods/config.toml`:

```toml
github_user = "daevski"
github_repo = "bashrc-modules"
github_branch = "main"
install_dir = "~/.bashrc.d"
```

### Browse and Install Modules

```bash
bash-mods
```

## Available Modules

### Version Control
- **git** - Git helpers, aliases, and multi-remote clone functions with SSH key management
- **gh-cli-tool** - GitHub CLI helper functions

### Development
- **python** - Python development tools (poetry, pytest, coverage)
- **pyenv** - Pyenv initialization and configuration

### Containers & Cloud
- **docker** - Docker cleanup and management utilities
- **aws** - AWS CLI shortcuts

### Security
- **ssh-agent** - Persistent SSH agent management
- **openssl_file_encryption** - File encryption/decryption with OpenSSL

### System
- **system** - General system utilities and helpers
- **audio-switching** - Audio device switching tools

## Manual Installation

If you prefer to install manually:

```bash
# Clone the repo
git clone git@github.com:daevski/bashrc-modules.git

# Copy desired modules to ~/.bashrc.d/
cp bashrc-modules/*.sh ~/.bashrc.d/

# Ensure your ~/.bashrc sources all files in ~/.bashrc.d/
```

Add to `~/.bashrc`:

```bash
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*.sh; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
    unset rc
fi
```

## Module Dependencies

Some modules depend on others:
- **git** requires **ssh-agent** for SSH key loading functionality

## License

Personal use - feel free to fork and adapt for your own needs.
