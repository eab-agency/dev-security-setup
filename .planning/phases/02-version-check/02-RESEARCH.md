# Phase 2 Research: Version Check Alerting

## Research Questions

1. How to query GitHub releases API for the latest version?
2. How to compare versions in bash?
3. How to cache the check to avoid hitting API rate limits on every run?

---

## Findings

### 1. GitHub Releases API

**Endpoint:** `https://api.github.com/repos/{owner}/{repo}/releases/latest`

Returns JSON with `tag_name` field containing the latest published release tag.

**Bash approaches (no jq dependency):**

```bash
# Using grep + sed (no jq required — important since script avoids extra deps)
curl -sL https://api.github.com/repos/eab-agency/dev-security-setup/releases/latest \
  | grep '"tag_name"' \
  | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/'
```

**With jq (if available):**
```bash
curl -sL https://api.github.com/repos/eab-agency/dev-security-setup/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//'
```

**Key considerations:**
- Use `curl -sL` (silent + follow redirects)
- Strip leading `v` from tag (e.g., `v3.1.0` → `3.1.0`) to compare with VERSION variable
- The `-sL` flags ensure no progress meter and redirect following
- If repo has no releases yet, the endpoint returns 404 — must handle gracefully

**Decision: Use grep+sed approach** — avoids adding jq as a dependency. The script already has no jq dependency and adding one just for version checking would conflict with the "zero-friction" goal.

### 2. Version Comparison in Bash

**Already solved in the codebase.** The script has `version_gte()` on line 72-74:

```bash
version_gte() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}
```

This uses `sort -V` (version sort), available on both macOS (coreutils) and Linux. No additional work needed — we reuse this function directly.

**Usage for version check:**
```bash
if ! version_gte "$VERSION" "$LATEST_VERSION"; then
    # Current version is older than latest → show alert
fi
```

### 3. Caching Strategy

**Problem:** GitHub API rate limit is 60 requests/hour for unauthenticated requests. If the script runs frequently across multiple projects, it could hit this limit.

**Solution: File-based timestamp caching**

Pattern observed in Homebrew and similar tools:
- Store last check timestamp and result in a cache file
- Only query API if cache is older than threshold (e.g., 24 hours)
- Cache location: `~/.cache/setup-security/` (XDG-compatible) or `$HOME/.setup-security-cache`

**Implementation approach:**

```bash
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/setup-security"
CACHE_FILE="$CACHE_DIR/latest-version"
CHECK_INTERVAL=86400  # 24 hours in seconds

should_check_version() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 0  # No cache, should check
    fi
    local last_check
    last_check=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
    local now
    now=$(date +%s)
    [ $((now - last_check)) -ge $CHECK_INTERVAL ]
}
```

**Note on `stat` portability:** macOS uses `stat -f %m` for modification time, Linux uses `stat -c %Y`. Need to handle both.

**Cache file format:** Plain text, single line containing the latest version number. Simple, no parsing needed.

**Homebrew's approach for reference:**
- Checks every 24 hours by default (configurable via `HOMEBREW_AUTO_UPDATE_SECS`)
- Stores last check time in a log file
- Background/silent check — never blocks the main operation

### 4. Graceful Degradation

Critical for a security tool — the version check must NEVER block or break the main functionality:

- **Network failure:** `curl` timeout (e.g., `--connect-timeout 3 --max-time 5`), silently skip check
- **API error (404, rate limited):** Skip check, don't cache error state
- **Parse failure:** If grep/sed returns empty, skip check
- **No internet:** Same as network failure — skip silently

**Pattern:**
```bash
check_for_updates() {
    # Fail silently — version check should never block security setup
    local latest
    latest=$(curl -sL --connect-timeout 3 --max-time 5 \
        "https://api.github.com/repos/eab-agency/dev-security-setup/releases/latest" \
        2>/dev/null | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

    [ -z "$latest" ] && return 0  # Couldn't fetch — skip silently

    # Cache the result
    mkdir -p "$CACHE_DIR"
    echo "$latest" > "$CACHE_FILE"

    # Compare
    if ! version_gte "$VERSION" "$latest"; then
        echo -e "${YELLOW}Update available: v$latest (current: v$VERSION)${NC}"
        echo -e "${YELLOW}Run: brew upgrade dev-security-setup${NC}"
        echo ""
    fi
}
```

### 5. Integration Point

**Where in the script:** After the banner (line 62) but before dependency checks (line 106). This way:
- User sees the version they're running (banner shows it)
- Immediately after, they see if an update is available
- Does not delay the actual setup work (short timeout on curl)

**UX pattern:**
```
=====================================
  Secret Detection Pipeline Setup
       version 3.0.0
=====================================

⚠ Update available: v3.1.0 (current: v3.0.0)
  Run: brew upgrade dev-security-setup

Checking dependencies...
```

---

## Recommended Approach

1. **Cache location:** `${XDG_CACHE_HOME:-$HOME/.cache}/setup-security/latest-version`
2. **Check interval:** 24 hours (86400 seconds) — matches Homebrew convention
3. **API call:** `curl -sL --connect-timeout 3 --max-time 5` with grep+sed parsing (no jq)
4. **Version comparison:** Reuse existing `version_gte()` function
5. **Failure mode:** Silent — never block or error on version check failure
6. **Integration:** After banner, before dependency checks
7. **Upgrade message:** Point to `brew upgrade dev-security-setup`

## Plan Structure

Two plans as defined in ROADMAP.md:

- **02-01:** Implement the version-check function (`check_for_updates`) with caching, API query, and version comparison
- **02-02:** Integrate into script startup — call after banner, handle the UX output

However, these are small enough that they could be consolidated into a single plan with 2-3 tasks. Recommend consolidation for efficiency.

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| No GitHub releases exist yet | High (Phase 3 creates them) | Function works fine — curl returns 404, grep finds nothing, function exits silently |
| `stat` flag differences macOS vs Linux | Medium | Use both syntaxes with fallback: `stat -f %m ... 2>/dev/null \|\| stat -c %Y ...` |
| User has no internet | Low | Timeout + silent failure = no impact |
| API rate limiting | Very low (24h cache) | Cache prevents repeated hits; 60/hr is plenty for cached checks |
