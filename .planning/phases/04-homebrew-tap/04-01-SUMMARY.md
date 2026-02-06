---
phase: 04-homebrew-tap
plan: 01
subsystem: infra
tags: [homebrew, formula, tap, distribution]

# Dependency graph
requires:
  - "01-script-preparation: v3.0.0 version bump, --version flag"
  - "03-release-infrastructure: release workflow, tarball URL pattern"
provides:
  - "eab-agency/homebrew-tools tap repository on GitHub"
  - "Formula/dev-security-setup.rb with pre-commit and trufflehog dependencies"
  - "brew install eab-agency/tools/dev-security-setup install path"
affects: [05-documentation, 06-validation]

# Tech tracking
tech-stack:
  added: [homebrew-formula-dsl]
  patterns: ["bin.install for shell script distribution", "depends_on for homebrew-core deps"]

key-files:
  created: [Formula/dev-security-setup.rb, README.md]
  modified: []

key-decisions:
  - "Formula name dev-security-setup (matches source repo name)"
  - "Binary name setup-security via bin.install rename"
  - "license :cannot_represent (no LICENSE file in source repo)"
  - "Zero-padded SHA256 placeholder until first release"

patterns-established:
  - "Homebrew tap at eab-agency/homebrew-tools with Formula/ subdirectory"
  - "Install command: brew install eab-agency/tools/dev-security-setup"

issues-created: []

# Metrics
duration: 2min
completed: 2026-02-06
---

# Phase 4 Plan 1: Homebrew Tap Summary

**Created eab-agency/homebrew-tools tap with dev-security-setup formula declaring pre-commit and trufflehog dependencies**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-06T16:16:14Z
- **Completed:** 2026-02-06T16:18:27Z
- **Tasks:** 2
- **Files created:** 2 (in tap repo)

## Accomplishments
- Created public GitHub repository `eab-agency/homebrew-tools`
- Formula installs `setup-security.sh` as `setup-security` to PATH via `bin.install`
- Dependencies `pre-commit` and `trufflehog` declared via `depends_on` (both in homebrew-core)
- Test block runs `--version` flag (from Phase 1)
- Local tap registered and validated: `brew tap eab-agency/tools` succeeds
- `brew audit` passes clean (zero-padded SHA256 placeholder passes format check)
- `brew info` shows correct metadata: name, desc, homepage, version 3.0.0, required deps

## Task Commits

Both tasks operated on the **tap repository** (eab-agency/homebrew-tools), not the source repo:

1. **Task 1: Create tap repo with formula** - `83533fa` + `725e6a3` (in tap repo)
2. **Task 2: Tap and validate formula** - no commits (local brew operations only)

## Files Created/Modified
- `Formula/dev-security-setup.rb` (in eab-agency/homebrew-tools) — Homebrew formula
- `README.md` (in eab-agency/homebrew-tools) — Tap documentation with install instructions

## Decisions Made
- Formula name `dev-security-setup` matches source repo name; binary renamed to `setup-security` via `bin.install`
- Used `license :cannot_represent` since source repo has no LICENSE file
- Zero-padded SHA256 (`0000...`) as placeholder — passes `brew audit` format check, will be replaced after first v3.0.0 release
- Fixed placeholder from readable text to valid 64-char hex to pass `brew audit`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SHA256 placeholder format for brew audit**
- **Found during:** Task 2 (brew audit)
- **Issue:** `PLACEHOLDER_UNTIL_FIRST_RELEASE` text failed audit (wrong length, invalid chars, not lowercase)
- **Fix:** Changed to zero-padded 64-char hex string `0000...0000`
- **Files modified:** Formula/dev-security-setup.rb (in tap repo)
- **Verification:** `brew audit` passes clean after fix
- **Committed in:** `725e6a3` (in tap repo)

---

**Total deviations:** 1 auto-fixed (blocking)
**Impact on plan:** Trivial format fix. No scope creep.

## Issues Encountered
None

## Next Phase Readiness
- Tap repo exists and is publicly accessible at `github.com/eab-agency/homebrew-tools`
- Formula is recognized by Homebrew: `brew info eab-agency/tools/dev-security-setup` works
- `brew audit` passes clean
- Formula NOT yet installable — SHA256 is placeholder, needs v3.0.0 release + real SHA256
- Next steps before formula works end-to-end:
  1. Push v3.0.0 tag to source repo → release workflow creates GitHub Release
  2. Compute SHA256: `curl -sL https://github.com/eab-agency/dev-security-setup/archive/refs/tags/v3.0.0.tar.gz | shasum -a 256`
  3. Update formula SHA256 in tap repo
- Ready for Phase 5 (Documentation — update README with Homebrew install instructions)

---
*Phase: 04-homebrew-tap*
*Completed: 2026-02-06*
