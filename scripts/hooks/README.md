# Git Hooks

This directory contains git hooks for the bashrc-modules repository.

## Setup

This repository is configured to use `git config core.hooksPath scripts/hooks` (requires git 2.9+).

If you've just cloned the repository, run:

```bash
git config core.hooksPath scripts/hooks
```

This tells git to use the hooks in this directory instead of `.git/hooks/`.

## Available Hooks

### pre-commit

Validates module version updates and registry synchronization before allowing commits.

**What it checks:**

1. **Module version updates**: If a module file (e.g., `modules/ssh-host-manager.sh`) is changed, ensures:
   - The version line was updated
   - The version in `registry.json` matches the module file version

2. **Component changes**: If component files (e.g., `modules/ssh-host-manager/agent.sh`) are changed:
   - Ensures the parent module's version was bumped

3. **Registry sync**: Validates that all modified modules have matching versions in `registry.json`

**If validation fails**, the hook provides helpful error messages with the exact command to fix the issue:

```bash
./scripts/update-registry.sh <module-name> <new-version>
```

## Requirements

- `jq` - JSON processor for validating registry.json
  - Install: `sudo dnf install jq`
