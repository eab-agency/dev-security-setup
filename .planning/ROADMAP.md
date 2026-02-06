# Roadmap: dev-security-setup — Homebrew Distribution

## Overview

Convert the existing `setup-security.sh` bash script from a clone-and-source distribution model to a Homebrew tap (`eab-agency/homebrew-tools`). The script stays bash — we're packaging it, not rewriting it. Phases move from adapting the script for standalone use, through release infrastructure, to the Homebrew formula itself.

## Domain Expertise

None

## Phases

- [x] **Phase 1: Script Preparation** - Adapt setup-security.sh for standalone Homebrew execution
- [ ] **Phase 2: Version Check** - Add version-check alerting to replace git-pull auto-update
- [ ] **Phase 3: Release Infrastructure** - Semver tagging, GitHub releases, and tarball generation
- [ ] **Phase 4: Homebrew Tap** - Create eab-agency/homebrew-tools with formula
- [ ] **Phase 5: Documentation** - Update README with Homebrew install instructions
- [ ] **Phase 6: Validation** - End-to-end testing of brew install workflow

## Phase Details

### Phase 1: Script Preparation
**Goal**: Make `setup-security.sh` work as a standalone binary installed to PATH — remove assumptions about being run from a cloned repo, remove git-pull auto-update logic, ensure all paths are resolved correctly
**Depends on**: Nothing (first phase)
**Research**: Unlikely (internal script modifications)
**Plans**: 1 plan (consolidated — script was already standalone)

Plans:
- [x] 01-01: Add --version flag, detect-secrets check, bump to v3.0.0

### Phase 2: Version Check
**Goal**: Replace the removed git-pull auto-update with a mechanism that checks for newer releases and alerts the user
**Depends on**: Phase 1
**Research**: Likely (GitHub API for version checking)
**Research topics**: GitHub API latest release endpoint, version comparison in bash, caching to avoid API rate limits on every run
**Plans**: 2 plans

Plans:
- [ ] 02-01: Implement version-check logic (query GitHub releases, compare with installed version)
- [ ] 02-02: Integrate version-check into script startup with caching (don't hit API every run)

### Phase 3: Release Infrastructure
**Goal**: Set up GitHub release workflow so tagged versions produce tarballs with SHA256 hashes that the Homebrew formula can reference
**Depends on**: Phase 2
**Research**: Likely (GitHub Actions release automation)
**Research topics**: GitHub Actions release workflow, automatic SHA256 generation, tarball URL patterns for Homebrew
**Plans**: 2 plans

Plans:
- [ ] 03-01: Create GitHub Actions workflow for automated releases on tag push
- [ ] 03-02: Generate and publish SHA256 hash alongside release tarball

### Phase 4: Homebrew Tap
**Goal**: Create the `eab-agency/homebrew-tools` repository with a formula that installs `setup-security` with `pre-commit` and `trufflehog` as dependencies
**Depends on**: Phase 3
**Research**: Likely (Homebrew formula conventions)
**Research topics**: Homebrew formula DSL, `depends_on` for non-core taps, formula test blocks, tap repository structure
**Plans**: 2 plans

Plans:
- [ ] 04-01: Create homebrew-tools repo with Formula/dev-security-setup.rb
- [ ] 04-02: Test formula installation and dependency resolution

### Phase 5: Documentation
**Goal**: Update README to replace clone-based installation with Homebrew instructions, document all CLI flags, and remove obsolete setup steps
**Depends on**: Phase 4
**Research**: Unlikely (documentation updates)
**Plans**: 2 plans

Plans:
- [ ] 05-01: Rewrite installation section with Homebrew instructions
- [ ] 05-02: Update usage docs, remove shell function references, document upgrade path

### Phase 6: Validation
**Goal**: End-to-end verification that `brew tap && brew install` works on a clean system, all flags behave correctly, version tracking works, and upgrade alerting fires
**Depends on**: Phase 5
**Research**: Unlikely (testing established patterns)
**Plans**: 1 plan

Plans:
- [ ] 06-01: Full integration test — install, configure a project, verify version tracking and upgrade alerting

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Script Preparation | 1/1 | Complete | 2026-02-06 |
| 2. Version Check | 0/2 | Not started | - |
| 3. Release Infrastructure | 0/2 | Not started | - |
| 4. Homebrew Tap | 0/2 | Not started | - |
| 5. Documentation | 0/2 | Not started | - |
| 6. Validation | 0/1 | Not started | - |
