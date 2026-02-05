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
git clone git@github.com:YOUR_ORG/dev-security-setup.git ~/dev-security-setup
```

Add this alias to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
alias setup-security='(cd ~/dev-security-setup && git pull -q) && ~/dev-security-setup/setup-security.sh'
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

The alias auto-updates the repo before running.

## Files created

| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml` | Hook configuration |
| `.trufflehogignore` | Paths to skip during scanning |
| `.secrets.baseline` | Baseline for detect-secrets |
| `.gitignore` | Updated with `.claude`, `.planning`, `.env` entries |
