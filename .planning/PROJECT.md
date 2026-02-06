# dev-security-setup — Homebrew Distribution

## What This Is

A one-command secret detection pipeline for any Git project, distributed via Homebrew. Users run `brew tap eab-agency/tools && brew install dev-security-setup` to get the `setup-security` CLI, which configures pre-commit hooks with TruffleHog secret scanning for any git repository — regardless of language or framework.

## Core Value

Zero-friction installation: `brew install` just works — all dependencies (pre-commit, trufflehog) are installed automatically, no manual steps, no shell function hacks, no cloned repos.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Create Homebrew tap repo (`eab-agency/homebrew-tools`) with formula for `dev-security-setup`
- [ ] Formula declares `pre-commit` and `trufflehog` as dependencies so `brew install` handles everything
- [ ] Script installs to `bin/` as `setup-security` (no `.sh` extension, directly on PATH)
- [ ] Existing `setup-security.sh` behavior preserved — same flags (`--force`, `--with-commitlint`, `--with-linting`), same output, same configs generated
- [ ] Per-project version tracking (`.security/version`) retained for security audit trail
- [ ] Version-check mechanism: script alerts users when running an outdated version (newer release available)
- [ ] Proper release tagging (semver) on this repo so Homebrew formula can reference stable tarballs
- [ ] Remove/update the old clone-based installation instructions in README
- [ ] Update README with Homebrew installation instructions

### Out of Scope

- Interactive TUI prompts (e.g., inquirer-style) — keep it flag-based, matching current behavior
- Node.js/npx rewrite — Homebrew distributes the bash script as-is, no rewrite needed
- Windows support — tool targets macOS developers using Homebrew
- Submitting to Homebrew core — this is a private tap under `eab-agency`

## Context

- The existing `setup-security.sh` is a 502-line bash script that configures pre-commit hooks with TruffleHog for secret detection, plus optional ESLint/Prettier linting hooks and commitlint
- Current distribution requires cloning the repo, adding a shell function to `~/.zshrc`, and sourcing it — high friction, error-prone
- The tool is language-agnostic (works on any git project), making Homebrew the natural distribution channel over npm/npx
- The team already uses `brew install pre-commit trufflehog`, so `brew install dev-security-setup` is the natural extension
- Existing version tracking in `.security/version` and auto-update via `git pull` need to be adapted for Homebrew distribution
- The script already has a `--force` flag for re-running on previously configured projects

## Constraints

- **Distribution**: Homebrew tap convention requires a separate repo named `eab-agency/homebrew-tools` with formula in `Formula/` directory
- **Compatibility**: The bash script runs as-is — no rewrite, just packaging and minor adjustments for Homebrew context (e.g., removing git-pull auto-update logic)
- **Security**: Version tracking is critical — users must know which version configured their security hooks, and be alerted when updates are available

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Homebrew over npx | Zero rewrite needed, language-agnostic, auto-installs deps, team already uses brew | -- Pending |
| Dedicated tap repo over self-hosted | Standard convention, can host multiple formulas later, cleaner separation | -- Pending |
| Keep per-project version tracking | Security tool — audit trail of which version configured hooks is critical | -- Pending |
| Add version-check alerting | Users should know when they're running outdated security tooling | -- Pending |

---
*Last updated: 2026-02-05 after initialization*
