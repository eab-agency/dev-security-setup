# Phase 4: Homebrew Tap - Research

**Researched:** 2026-02-06
**Domain:** Homebrew tap creation, formula DSL for bash script distribution
**Confidence:** HIGH

<research_summary>
## Summary

Researched Homebrew tap creation and formula conventions for distributing a bash script (`setup-security.sh`) with `pre-commit` and `trufflehog` as dependencies. Both dependencies are in homebrew-core, making dependency resolution straightforward.

The standard approach is a `homebrew-tools` repository with a `Formula/` subdirectory containing a Ruby formula file. The formula uses `bin.install` to place the script in PATH and `depends_on` for automatic dependency installation. Users install with a single command: `brew install eab-agency/tools/dev-security-setup`.

Key finding: This is a simple formula — no compilation, no patches, no complex install logic. The entire formula is ~15 lines of Ruby. The main risks are SHA256 mismatches and class/filename naming mismatches.

**Primary recommendation:** Create `eab-agency/homebrew-tools` repo with `Formula/dev-security-setup.rb`, use `bin.install "setup-security.sh" => "setup-security"`, depend on `pre-commit` and `trufflehog` from homebrew-core.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Homebrew formula DSL | Ruby | Define formula metadata, deps, install, test | Only option for Homebrew formulas |
| `bin.install` | built-in | Install script to `$(brew --prefix)/bin/` | Standard method, auto-chmod +x |

### Dependencies (homebrew-core)
| Formula | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `pre-commit` | 4.5.1 | Pre-commit hook framework | In homebrew-core, pulls python@3.14 |
| `trufflehog` | 3.93.0 | Secret detection scanner | In homebrew-core, Go binary |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Homebrew tap | npm/pip package | Homebrew is standard for macOS CLI tools, handles deps natively |
| `bin.install` | `libexec.install` + shell wrapper | Overkill for a single script |
| Custom tap | homebrew-core PR | homebrew-core has strict acceptance criteria, tap is simpler for org tools |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Tap Repository Structure
```
eab-agency/homebrew-tools/
├── Formula/
│   └── dev-security-setup.rb    # The formula
└── README.md                     # Usage instructions
```

- Repository MUST be named `homebrew-tools` (Homebrew strips `homebrew-` prefix in commands)
- Formulas go in `Formula/` subdirectory (recommended over root)
- Default branch: `main` (Homebrew convention since 2025)
- No LICENSE file required for taps (unlike homebrew-core submissions)

### Formula Pattern for Shell Scripts
```ruby
class DevSecuritySetup < Formula
  desc "One-command secret detection pipeline for Git projects"
  homepage "https://github.com/eab-agency/dev-security-setup"
  url "https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "COMPUTED_AFTER_RELEASE"
  license :cannot_represent  # or specific SPDX identifier if LICENSE added

  depends_on "pre-commit"
  depends_on "trufflehog"

  def install
    bin.install "setup-security.sh" => "setup-security"
  end

  test do
    system bin/"setup-security", "--version"
  end
end
```

### Naming Conventions
- **Filename:** `dev-security-setup.rb` (lowercase, hyphens)
- **Class name:** `DevSecuritySetup` (strict CamelCase of filename)
- **Installed binary:** `setup-security` (via `bin.install` rename)
- **Formula name in brew commands:** `dev-security-setup`

### Installation Flow
```
# One-step (recommended for users):
brew install eab-agency/tools/dev-security-setup
# → auto-taps eab-agency/tools
# → auto-installs pre-commit + trufflehog if missing
# → installs setup-security to PATH

# Two-step (explicit):
brew tap eab-agency/tools
brew install dev-security-setup

# Upgrade:
brew update && brew upgrade dev-security-setup
```

### Anti-Patterns to Avoid
- **Placing formulas at repo root** — use `Formula/` subdirectory
- **Naming repo `tools` instead of `homebrew-tools`** — `homebrew-` prefix is mandatory
- **Using `libexec` + shell wrapper for a simple script** — `bin.install` is sufficient
- **Hardcoding SHA256 before release exists** — compute after `git push --tags` and release is created
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Script installation | Custom `cp` + `chmod` | `bin.install "script" => "name"` | Handles permissions, PATH, cleanup |
| Dependency management | Instructions to "install pre-commit first" | `depends_on "pre-commit"` | Auto-installs, version tracking |
| Formula creation | Writing from scratch | `brew create <url>` scaffold | Generates skeleton with correct structure |
| SHA256 computation | Manual download + checksum | `curl -sL <url> \| shasum -a 256` | One-liner, no temp files |
| Tap testing | Pushing and hoping | `brew install --build-from-source` locally | Catches issues before users see them |

**Key insight:** Homebrew formula for a single bash script should be ~15 lines of Ruby. If it's longer, you're overcomplicating it.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Class Name / Filename Mismatch
**What goes wrong:** Formula fails to load with "Error: No available formula"
**Why it happens:** Ruby class name doesn't match CamelCase conversion of filename
**How to avoid:** `dev-security-setup.rb` → class `DevSecuritySetup` (strict conversion: hyphen-separated → CamelCase)
**Warning signs:** `brew install` can't find the formula despite file existing

### Pitfall 2: SHA256 Computed Before Release Exists
**What goes wrong:** SHA256 doesn't match when users install
**Why it happens:** Computing SHA256 from tag URL before GitHub Release is created, or tarball changes after release
**How to avoid:** Only compute SHA256 after release workflow completes and tarball is stable
**Warning signs:** `brew install` fails with "SHA256 mismatch"

### Pitfall 3: Repository Not Named `homebrew-*`
**What goes wrong:** `brew tap eab-agency/tools` fails with "Repository not found"
**Why it happens:** Homebrew auto-prepends `homebrew-` to the tap name when cloning
**How to avoid:** GitHub repo MUST be named `homebrew-tools` — users reference it as `eab-agency/tools`
**Warning signs:** 404 when tapping

### Pitfall 4: Missing `permissions: contents: write` on Tap Repo
**What goes wrong:** Automated formula updates via GitHub Actions fail
**Why it happens:** Default GitHub Actions token is read-only
**How to avoid:** If adding auto-bump later, ensure workflow has write permissions on the tap repo
**Warning signs:** 403 error in formula-bump action

### Pitfall 5: Shebang Portability
**What goes wrong:** Script fails on systems where `/bin/bash` is old (pre-4.0)
**Why it happens:** macOS ships bash 3.2, users may have Homebrew bash 5.x at different path
**How to avoid:** Use `#!/usr/bin/env bash` for portability, or ensure script doesn't use bash 4+ features
**Warning signs:** Syntax errors on some machines but not others
**Note:** Current script uses `#!/bin/bash` — works fine if no bash 4+ features are used

### Pitfall 6: No LICENSE in Source Repo
**What goes wrong:** `brew audit` warns about missing license; `license` field in formula can't reference an SPDX identifier
**Why it happens:** Source repository has no LICENSE file
**How to avoid:** Add LICENSE to source repo, or use `license :cannot_represent` in formula
**Warning signs:** `brew audit --strict` warnings
**Note:** Current project has no LICENSE file — either add one or use `:cannot_represent`
</common_pitfalls>

<code_examples>
## Code Examples

### Complete Formula (Recommended)
```ruby
# Source: Homebrew Formula Cookbook + verified patterns
class DevSecuritySetup < Formula
  desc "One-command secret detection pipeline for Git projects"
  homepage "https://github.com/eab-agency/dev-security-setup"
  url "https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "COMPUTED_AFTER_RELEASE"
  license :cannot_represent

  depends_on "pre-commit"
  depends_on "trufflehog"

  def install
    bin.install "setup-security.sh" => "setup-security"
  end

  test do
    system bin/"setup-security", "--version"
  end
end
```

### Computing SHA256 After Release
```bash
# After v3.0.0 tag pushed and release created:
curl -sL https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz | shasum -a 256
```

### Local Testing Workflow
```bash
# 1. Create tap repo locally (or clone from GitHub)
brew tap-new eab-agency/tools  # or clone your repo

# 2. Copy formula to tap
cp Formula/dev-security-setup.rb $(brew --repository eab-agency/tools)/Formula/

# 3. Install from source
brew install --build-from-source eab-agency/tools/dev-security-setup

# 4. Test
brew test eab-agency/tools/dev-security-setup

# 5. Audit
brew audit --strict eab-agency/tools/dev-security-setup

# 6. Verify binary works
setup-security --version
```

### One-Line Install (User-Facing)
```bash
brew install eab-agency/tools/dev-security-setup
# Auto-taps, auto-installs deps, places `setup-security` in PATH
```
</code_examples>

<sota_updates>
## State of the Art (2025-2026)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Formulas at repo root | `Formula/` subdirectory | 2020+ | Better organization, Homebrew recommendation |
| `master` default branch | `main` default branch | 2025 | Homebrew completed migration June 2025 |
| Manual formula updates | `dawidd6/action-homebrew-bump-formula` | 2024+ | Auto-creates PR to tap on release |
| Custom install scripts | `bin.install` one-liner | Always | Standard Homebrew pattern |

**New tools/patterns:**
- `brew tap-new` command: Scaffolds a new tap repo with correct structure
- GitHub Actions for cross-repo formula bumping: Automates the VERSION → SHA256 → formula PR cycle

**Deprecated/outdated:**
- Formulas at repo root: Still works but not recommended
- `master` branch: Homebrew migrated to `main`
</sota_updates>

<open_questions>
## Open Questions

1. **LICENSE file for source repo?**
   - What we know: No LICENSE file exists in the source repo. Homebrew formula `license` field expects SPDX identifier.
   - What's unclear: Whether the project owner wants to add a license.
   - Recommendation: Use `license :cannot_represent` for now. If LICENSE is added later, update to SPDX identifier (e.g., `license "MIT"`).

2. **Shebang: `#!/bin/bash` vs `#!/usr/bin/env bash`?**
   - What we know: Current script uses `#!/bin/bash`. macOS ships bash 3.2. Homebrew users may have bash 5.x.
   - What's unclear: Whether the script uses any bash 4+ features that would break under `/bin/bash` on macOS.
   - Recommendation: Keep `#!/bin/bash` unless bash 4+ features are needed. It's simpler and works on stock macOS.

3. **Formula name: `dev-security-setup` vs `setup-security`?**
   - What we know: The repo is `dev-security-setup`, the binary is `setup-security`, no conflicts with either name.
   - What's unclear: Which name is more intuitive for `brew install <name>`.
   - Recommendation: Use `dev-security-setup` (matches repo name). Binary name remains `setup-security` via `bin.install` rename.

4. **Where to create the `homebrew-tools` repo?**
   - What we know: Must be at `github.com/eab-agency/homebrew-tools`. This is a different repo from the source.
   - What's unclear: Whether this should be created manually on GitHub or as part of this phase.
   - Recommendation: Phase 4 planning should include repo creation as a manual prerequisite. Formula content can be prepared in the source repo's `.planning/` or as a separate task.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [Homebrew Docs: Formula Cookbook](https://docs.brew.sh/Formula-Cookbook) — formula DSL, install methods, test blocks
- [Homebrew Docs: Taps](https://docs.brew.sh/Taps) — tap structure, naming, user flow
- [Homebrew Docs: How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) — repo structure, Formula/ directory
- [Homebrew Formulae: pre-commit](https://formulae.brew.sh/formula/pre-commit) — confirmed in homebrew-core, v4.5.1
- [Homebrew Formulae: trufflehog](https://formulae.brew.sh/formula/trufflehog) — confirmed in homebrew-core, v3.93.0
- Local verification: `brew info pre-commit` and `brew info trufflehog` confirmed both installed from homebrew-core

### Secondary (MEDIUM confidence)
- [Homebrew Discussions: Formulae to install a bash shell script](https://github.com/orgs/Homebrew/discussions/5388) — community confirmation of `bin.install` pattern
- [Blog: How to Publish a Bash Script to Homebrew](https://blog.chaitanyashahare.com/posts/how-to-publish-a-bash-script-to-homebrew/) — step-by-step walkthrough
- [Blog: Creating a simple Homebrew Formula](https://mvogelgesang.com/blog/20240419/creating-a-simple-homebrew-formula/) — verified against official docs

### Tertiary (LOW confidence - needs validation)
- None — all findings verified against official Homebrew documentation
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Homebrew formula DSL (Ruby)
- Ecosystem: homebrew-core dependencies (pre-commit, trufflehog)
- Patterns: Tap repo structure, `bin.install` for scripts, `depends_on` for deps
- Pitfalls: Naming, SHA256, repo naming, license, shebang

**Confidence breakdown:**
- Standard stack: HIGH — official Homebrew docs
- Architecture: HIGH — well-documented tap conventions
- Pitfalls: HIGH — verified from docs and community discussions
- Code examples: HIGH — derived from official cookbook

**Research date:** 2026-02-06
**Valid until:** 2026-03-06 (30 days — Homebrew ecosystem stable)
</metadata>

---

*Phase: 04-homebrew-tap*
*Research completed: 2026-02-06*
*Ready for planning: yes*
