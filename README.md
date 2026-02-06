# Dev Security Setup

One-command secret detection pipeline for any project.

## What it does

- Installs pre-commit hooks for secret detection on every commit
- Installs pre-push hooks for comprehensive secret scanning with verification
- Creates sensible ignore files to reduce false positives
- Updates `.gitignore` to exclude sensitive directories

## Installation

Install via [Homebrew](https://brew.sh):

```bash
brew install eab-agency/tools/dev-security-setup
```

This installs the `setup-security` command and its dependencies (`pre-commit`, `trufflehog`) automatically.

## Usage

From any git project root:

```bash
setup-security
```

### Options

| Flag | Description |
|------|-------------|
| `-f`, `--force` | Force re-run even if already installed |
| `--with-commitlint` | Add commitlint hook for conventional commits |
| `--with-linting` | Add ESLint and Prettier hooks |
| `-v`, `--version` | Show version |
| `-h`, `--help` | Show help message |

### Examples

```bash
setup-security                                    # Basic security setup
setup-security --with-commitlint                  # Add commit message linting
setup-security --with-linting                     # Add code linting (ESLint/Prettier)
setup-security --with-commitlint --with-linting   # Add both
```

### Re-running on existing projects

The script tracks which version was installed via `.security/version`. Running again will:

- **Same version**: Skip with "already up to date" message
- **Newer version**: Automatically upgrade hooks and configuration
- **Force re-run**: Use `setup-security --force` or `setup-security -f`

### Update notifications

The script checks for newer releases once every 24 hours (cached). If a newer version is available, you'll see:

```
Update available: vX.Y.Z (current: vX.Y.Z)
Run: brew upgrade dev-security-setup
```

## Upgrading

```bash
brew upgrade dev-security-setup
```

After upgrading, run `setup-security` in your projects to apply any new hook configurations. The script detects the version change and re-configures automatically.

## Uninstalling

```bash
brew uninstall dev-security-setup
```

Per-project files (`.security/`, `.pre-commit-config.yaml`) are not removed — they belong to each project.

## Testing hooks manually

```bash
# Test commit hooks
pre-commit run --all-files

# Test push hooks
pre-commit run --hook-stage pre-push
```

## Files created

| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml` | Hook configuration (standard location, can add other hooks) |
| `.security/trufflehogignore` | Paths to skip during trufflehog scanning |
| `.security/secrets.baseline` | Baseline for detect-secrets |
| `.security/version` | Tracks installed version for upgrades |
| `.gitignore` | Updated with `.claude`, `.planning`, `.env` entries |
