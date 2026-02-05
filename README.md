# Dev Security Setup

One-command secret detection pipeline for any project.

## What it does

- Installs pre-commit hooks for secret detection on every commit
- Installs pre-push hooks for comprehensive secret scanning with verification
- Creates sensible ignore files to reduce false positives
- Updates `.gitignore` to exclude sensitive directories

## Requirements

```bash
brew install pre-commit trufflehog
```

## Setup

Clone this repo once:

```bash
git clone git@github.com:eab-agency/dev-security-setup.git ~/dev-security-setup
```

Add this function to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
setup-security() {
  (cd ~/dev-security-setup && git pull -q) && ~/dev-security-setup/setup-security.sh "$@"
}
```

Reload your shell:

```bash
source ~/.zshrc  # or source ~/.bashrc
```

## Usage

From any git project root:

```bash
setup-security
```

The function auto-updates the repo before running.

### Re-running on existing projects

The script tracks which version was installed via `.security/version`. Running again will:

- **Same version**: Skip with "already up to date" message
- **Newer version available**: Automatically upgrade
- **Force re-run**: Use `setup-security --force` or `setup-security -f`

### Testing hooks manually

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
