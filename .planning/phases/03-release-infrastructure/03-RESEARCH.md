# Phase 3: Release Infrastructure - Research

**Researched:** 2026-02-06
**Domain:** GitHub Actions release automation + Homebrew formula tarball requirements
**Confidence:** HIGH

<research_summary>
## Summary

Researched how to automate GitHub releases on tag push and how Homebrew formulas consume release tarballs. The standard approach is a simple GitHub Actions workflow triggered by `v*` tag push that creates a release with auto-generated notes. Homebrew formulas reference GitHub's auto-generated archive tarballs at `archive/refs/tags/vX.Y.Z.tar.gz`.

Key finding: GitHub auto-generates tarballs for all tags — no custom archive needed. The SHA256 checksum may not be byte-stable across re-downloads, but for a private tap with infrequent releases, this is acceptable. The formula can be updated manually or via `dawidd6/action-homebrew-bump-formula` action.

**Primary recommendation:** Use `softprops/action-gh-release@v2` for release creation, reference auto-generated tarballs in the formula, and consider `dawidd6/action-homebrew-bump-formula` for auto-updating the tap formula on new releases.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `softprops/action-gh-release` | v2 | Create GitHub releases from tags | Most popular, actively maintained (v2.5.0 Dec 2025), simpler than alternatives |
| `actions/checkout` | v4 | Checkout repo in workflow | Required for any workflow |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `dawidd6/action-homebrew-bump-formula` | v4 | Auto-update Homebrew formula on release | If you want to auto-create PR to tap repo when releasing |
| `mislav/bump-homebrew-formula-action` | v3 | Lightweight formula bumper | Alternative — doesn't need Homebrew installed, uses GitHub API directly |
| `gh` CLI | built-in | Create releases from command line | Manual releases or simple workflows |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `softprops/action-gh-release` | `gh release create` in bash | gh CLI is simpler but action has better asset upload support |
| `softprops/action-gh-release` | `actions/create-release` (official) | Official action is older, less maintained, requires separate asset upload step |
| Auto-generated tarball | Custom uploaded tarball | Custom guarantees SHA256 stability but adds complexity; auto-generated is fine for private taps |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Release Workflow

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags:
      - "v*"
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

### Tarball URL Pattern for Homebrew

GitHub auto-generates tarballs at:
```
https://github.com/{owner}/{repo}/archive/refs/tags/v{version}.tar.gz
```

Example for this project:
```
https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz
```

### Tarball Directory Structure

When extracted, the tarball root directory follows the pattern `{repo}-{version}/` (with `v` prefix stripped from tag):
```
dev-security-setup-3.0.0/
├── setup-security.sh
├── README.md
└── ...
```

In a Homebrew formula's `install` method, the working directory is already this extracted root — no need to `cd` into it.

### Formula Install Pattern

```ruby
class DevSecuritySetup < Formula
  desc "One-command secret detection pipeline for Git projects"
  homepage "https://github.com/eab-agency/dev-security-setup"
  url "https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "abc123..."  # Computed after release
  license "MIT"

  depends_on "pre-commit"
  depends_on "trufflehog"

  def install
    bin.install "setup-security.sh" => "setup-security"
  end

  test do
    assert_match "version", shell_output("#{bin}/setup-security --version")
  end
end
```

### Release + Formula Update Flow

```
Developer tags v3.1.0
    ↓
GitHub Actions: release.yml triggers
    ↓
Creates GitHub Release with auto-generated notes
    ↓
(Option A) Manual: compute SHA256, update formula
(Option B) Auto: dawidd6/action-homebrew-bump-formula creates PR to tap repo
    ↓
Formula updated → users get new version via `brew upgrade`
```

### Anti-Patterns to Avoid
- **Uploading custom tarballs when auto-generated ones work fine** — adds complexity for no benefit in a simple bash script project
- **Using `actions/create-release` (official)** — it's older, less maintained, and requires a separate step for asset upload
- **Hardcoding SHA256 in the release workflow** — compute it after the release is published, not during
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Release creation | Custom API calls to GitHub | `softprops/action-gh-release@v2` | Handles assets, notes, drafts, pre-releases |
| Release notes | Custom changelog script | `generate_release_notes: true` | GitHub auto-generates from PRs and commits |
| Formula version bumping | Custom script to edit formula | `dawidd6/action-homebrew-bump-formula` | Handles SHA256 computation, PR creation, version parsing |
| Tarball creation | Custom `tar` command in CI | GitHub auto-generated archives | GitHub creates them automatically for every tag |

**Key insight:** For a single bash script distributed via Homebrew, the release infrastructure should be minimal. GitHub provides everything out of the box — releases, tarballs, notes. The only custom piece is the workflow YAML.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: SHA256 Instability of Auto-Generated Archives
**What goes wrong:** GitHub's auto-generated tarballs may have different byte layouts across downloads (same content, different compression)
**Why it happens:** GitHub doesn't guarantee byte-level stability for auto-generated archives
**How to avoid:** For private taps with infrequent releases, this is rarely an issue. If it becomes one, switch to uploading a custom tarball as a release asset. Alternatively, use `brew bump-formula-pr` which handles recomputation.
**Warning signs:** `brew install` fails with SHA256 mismatch error

### Pitfall 2: Missing `permissions: contents: write`
**What goes wrong:** Release creation step fails with 403/permission error
**Why it happens:** GitHub Actions workflows default to read-only permissions
**How to avoid:** Add `permissions: contents: write` to the workflow or job
**Warning signs:** "Resource not accessible by integration" error

### Pitfall 3: GITHUB_TOKEN Can't Trigger Other Workflows
**What goes wrong:** Release workflow completes but formula-bump workflow doesn't trigger
**Why it happens:** Events created with GITHUB_TOKEN don't trigger subsequent workflows (anti-recursion protection)
**How to avoid:** If you need release → formula bump chaining, either: (1) put both in the same workflow, or (2) use a Personal Access Token instead of GITHUB_TOKEN for the release step
**Warning signs:** Formula bump workflow never runs despite being configured for `release` event

### Pitfall 4: Tag vs Release Confusion
**What goes wrong:** Formula references a tag that has no release, or SHA256 computed from unreleased tag
**Why it happens:** Tags and releases are separate concepts in Git/GitHub
**How to avoid:** Always create releases from tags via the workflow, compute SHA256 after the release is published
**Warning signs:** Tarball URL returns 404
</common_pitfalls>

<code_examples>
## Code Examples

### Minimal Release Workflow (Recommended for This Project)

```yaml
# Source: GitHub docs + softprops/action-gh-release docs
name: Release
on:
  push:
    tags:
      - "v*"
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

### Computing SHA256 After Release

```bash
# After pushing a tag and release is created:
curl -sL https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz \
  | shasum -a 256
# Output: abc123def456... -
```

### Release Workflow with Formula Auto-Bump

```yaml
# Source: dawidd6/action-homebrew-bump-formula docs
name: Release
on:
  push:
    tags:
      - "v*"
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
      - uses: dawidd6/action-homebrew-bump-formula@v4
        with:
          token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
          formula: dev-security-setup
          tap: eab-agency/homebrew-tools
          tag: ${{ github.ref_name }}
          url: https://github.com/eab-agency/dev-security-setup/archive/refs/tags/${{ github.ref_name }}.tar.gz
```

### Creating a Tag and Triggering Release

```bash
# Ensure VERSION in script matches tag
git tag v3.0.0
git push origin v3.0.0
# → release.yml triggers automatically
```
</code_examples>

<sota_updates>
## State of the Art (2025-2026)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `actions/create-release` (official) | `softprops/action-gh-release@v2` | 2023+ | Better maintained, simpler API, built-in asset upload |
| Manual release notes | `generate_release_notes: true` | 2022+ | GitHub auto-generates from PRs/commits |
| Custom SHA256 scripts | `dawidd6/action-homebrew-bump-formula@v4` | 2024+ | Handles SHA256 + PR creation automatically |

**New tools/patterns:**
- `softprops/action-gh-release` v2.5.0 (Dec 2025) — latest, well maintained
- GitHub's native release notes customization via `.github/release.yml` config

**Deprecated/outdated:**
- `actions/create-release` — still works but less actively maintained
- Manual SHA256 computation workflows — formula bump actions handle this
</sota_updates>

<open_questions>
## Open Questions

1. **Auto-bump vs manual formula update?**
   - What we know: Both approaches work. Auto-bump requires a PAT with `public_repo` scope stored as a secret in the source repo.
   - What's unclear: Whether `dawidd6/action-homebrew-bump-formula` works when the tap repo doesn't exist yet (Phase 4 creates it).
   - Recommendation: Start with manual formula updates. Add auto-bump after the tap repo exists and is validated. Can be added in Phase 4 or as a follow-up.

2. **SHA256 stability for our use case**
   - What we know: Auto-generated tarballs may have unstable checksums. For private taps with controlled releases, this is rarely an issue.
   - What's unclear: How often GitHub actually changes the compression, and whether it affects `archive/refs/tags/` URLs.
   - Recommendation: Use auto-generated tarballs. If SHA256 mismatches ever occur, switch to uploading a custom tarball as a release asset.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [GitHub Docs: Events that trigger workflows](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows) — tag push triggers
- [GitHub Docs: Automatically generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) — release notes config
- [GitHub Docs: Downloading source code archives](https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives) — tarball structure
- [Homebrew Docs: Formula Cookbook](https://docs.brew.sh/Formula-Cookbook) — formula structure, url/sha256
- [Homebrew Docs: How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) — tap repo conventions
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) — release action docs (v2.5.0, Dec 2025)

### Secondary (MEDIUM confidence)
- [dawidd6/action-homebrew-bump-formula](https://github.com/dawidd6/action-homebrew-bump-formula) — formula bump action
- [mislav/bump-homebrew-formula-action](https://github.com/mislav/bump-homebrew-formula-action) — alternative bump action
- [GitHub Community: Checksum mismatches on .tar.gz files](https://github.com/orgs/community/discussions/45830) — SHA256 stability discussion

### Tertiary (LOW confidence - needs validation)
- None — all findings verified against primary sources
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: GitHub Actions + GitHub Releases API
- Ecosystem: softprops/action-gh-release, dawidd6/action-homebrew-bump-formula
- Patterns: Tag-triggered release, tarball URL format, formula install
- Pitfalls: SHA256 instability, permissions, token limitations

**Confidence breakdown:**
- Release workflow: HIGH — official GitHub docs + widely used action
- Tarball format: HIGH — GitHub docs + Homebrew docs
- Formula patterns: HIGH — Homebrew cookbook docs
- Auto-bump: MEDIUM — action exists and is maintained, but untested for our exact setup

**Research date:** 2026-02-06
**Valid until:** 2026-03-06 (30 days — stable ecosystem)
</metadata>

---

*Phase: 03-release-infrastructure*
*Research completed: 2026-02-06*
*Ready for planning: yes*
