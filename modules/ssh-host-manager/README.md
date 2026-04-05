# SSH Host Manager

A shell module suite for managing SSH hosts, Git credentials, and repository workflows. It handles the repetitive work of SSH config entries, key management, and repository setup so you don't have to.

## Table of Contents

- [Components](#components)
- [Configuration](#configuration)
- [Workflows](#workflows)
  - [Setting up a new Git host](#setting-up-a-new-git-host-eg-github-self-hosted-gitea)
  - [Setting up a regular SSH host](#setting-up-a-regular-ssh-host-servers-lan-machines)
  - [Listing configured hosts](#listing-configured-hosts)
  - [Removing a host](#removing-a-host)
  - [Cloning a repository](#cloning-a-repository)
  - [Syncthing workflow](#syncthing-workflow)
  - [Automatic SSH key loading](#automatic-ssh-key-loading)
- [SSH config format](#ssh-config-format)

---

## Components

| File         | Purpose                                                                             |
| ------------ | ----------------------------------------------------------------------------------- |
| `agent.sh`   | SSH agent lifecycle, key loading, `ssh`/`git` command wrappers                      |
| `manager.sh` | Interactive host configuration (`ssh-host-add`, `ssh-host-list`, `ssh-host-remove`) |
| `git.sh`     | Git repository cloning with SSH key resolution and hook detection                   |
| `sync.sh`    | Syncthing repo restoration (`git-setup`)                                            |

Components are loaded alphabetically by the main `ssh-host-manager.sh` module. There is no declared load order dependency — each file is self-contained.

---

## Configuration

Set these before sourcing the module to override defaults:

```bash
export BASHRCMODS_CODE_BASE_DIR="$HOME/projects"                   # Base directory for git clones (default: ~/code)
export BASHRCMODS_SSH_AUTO_ALIAS=false                # Prompt for host alias instead of using org name
export BASHRCMODS_SSH_AUTO_CLONE_DIR=false            # Prompt for clone directory instead of auto-setting
export BASHRCMODS_SSH_CLONE_DIR_BASE="$HOME/work"     # Override base dir for clone directory auto-detection
```

---

## Workflows

### Setting up a new Git host (e.g. GitHub, self-hosted Gitea)

```bash
ssh-host-add github.com
```

The command detects that `github.com` is a Git host and walks you through:

1. **Organization/username** — used as the host alias and to auto-match an existing SSH key
2. **SSH key selection** — picks a key whose filename contains the org name, or lets you choose/generate one
3. **Clone directory** — defaults to `$BASHRCMODS_CODE_BASE_DIR/<org>` (e.g. `~/code/raremonarch`)

After confirming, it writes a managed entry to `~/.ssh/config`:

```sshconfig
# Managed by ssh-host-manager (type=git, org=raremonarch, clone_dir=~/code/raremonarch)
Host raremonarch
    HostName github.com
    User git
    IdentityFile ~/.ssh/gh_raremonarch_ed25519
    IdentitiesOnly yes
```

For Git hosts you still need to add the public key to your provider account manually. (i.e., github.com > settings > create ssh key.)

### Setting up a regular SSH host (servers, LAN machines)

```bash
ssh-host-add macmini.lan
# or with flags to skip prompts:
ssh-host-add macmini.lan --host-alias mac --user david --key ~/.ssh/id_ed25519
```

Prompts for alias, username, port, and key selection. Optionally copies the public key to the remote host via `ssh-copy-id`.

### Listing configured hosts

```bash
ssh-host-list
```

Shows all hosts managed by this module with their type, hostname, key status, and clone directory (for Git hosts).

### Removing a host

```bash
ssh-host-remove raremonarch
```

Removes the managed block from `~/.ssh/config`. The clone directory is left intact.

---

### Cloning a repository

```bash
clone-repo <owner> <repo-name>
```

Looks up the SSH host alias for the owner (lowercased), resolves the correct SSH key from config, clones the repo into the configured clone directory, and writes a `.gitremote` file (see Syncthing workflow below).

If the owner has no configured SSH host alias, it falls back to `git@github.com`.

```bash
clone-repo raremonarch bashrc-modules
# → clones git@raremonarch:raremonarch/bashrc-modules.git
# → into ~/code/raremonarch/bashrc-modules

clone-repo EBSCOIS some-work-repo
# → clones git@ebscois:EBSCOIS/some-work-repo.git
# → into configured clone dir for the ebscois host
```

After a successful clone, if the repo contains a known hook setup, the command prints the install command rather than silently skipping it:

```text
  ⚙ Git hooks detected (scripts/hooks). To install, run:
      cd ~/code/raremonarch/bashrc-modules && git config core.hooksPath scripts/hooks
```

Detected hook patterns and their suggested commands:

| Pattern                           | Command                                   |
| --------------------------------- | ----------------------------------------- |
| `scripts/hooks/` directory        | `git config core.hooksPath scripts/hooks` |
| `.githooks/` directory            | `git config core.hooksPath .githooks`     |
| `.git-hooks/` directory           | `git config core.hooksPath .git-hooks`    |
| `.pre-commit-config.yaml`         | `pre-commit install`                      |
| `lefthook.yml` or `lefthook.toml` | `lefthook install`                        |
| `.husky/` directory               | `npm run prepare`                         |

---

### Syncthing workflow

If you use Syncthing to sync code directories across machines (excluding `.git/`), repos on secondary machines arrive as plain directories without git metadata.

`clone-repo` writes a `.gitremote` file into every cloned repo:

```text
git@raremonarch:raremonarch/bashrc-modules.git
main
```

Line 1 is the remote URL, line 2 is the default branch. Syncthing picks this up automatically. Add `**.gitremote` to your global gitignore so it never gets accidentally committed:

```bash
echo '**.gitremote' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

On the secondary machine, restore any synced repo with:

```bash
cd ~/code/raremonarch/bashrc-modules
git-setup
# or with an explicit path:
git-setup ~/code/raremonarch/bashrc-modules
```

This runs `git init`, adds the remote, fetches, and wires up the branch ref — without touching the working tree files. Any uncommitted changes from the primary machine show up correctly in `git status`.

---

### Automatic SSH key loading

The module wraps the `ssh` and `git` commands to auto-load keys on demand:

- **`ssh <host>`** — looks up the `IdentityFile` for that host in `~/.ssh/config` and loads it into the agent if not already present
- **`git push/pull/fetch`** — resolves the key from the repo's remote URL and loads it before the operation

To load all managed keys at once (e.g. at login):

```bash
ssh-keys-load
```

---

## SSH config format

Managed entries are marked with a comment header so the module can identify and remove them cleanly:

```sshconfig
# Managed by ssh-host-manager (type=git, org=raremonarch, clone_dir=~/code/raremonarch)
Host raremonarch
    HostName github.com
    User git
    IdentityFile ~/.ssh/gh_raremonarch_ed25519
    IdentitiesOnly yes
```

Entries without this header are never touched by `ssh-host-remove`.
