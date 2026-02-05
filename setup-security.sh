#!/bin/bash
set -e

# Version of this setup script - increment when making changes
VERSION="2.1.3"
SECURITY_DIR=".security"
VERSION_FILE="$SECURITY_DIR/version"
CONFIG_FILE=".pre-commit-config.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
FORCE=false
for arg in "$@"; do
    case $arg in
        --force|-f)
            FORCE=true
            shift
            ;;
    esac
done

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Secret Detection Pipeline Setup${NC}"
echo -e "${GREEN}       version $VERSION${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not a git repository. Please run this from a git project root.${NC}"
    exit 1
fi

# Version comparison function (returns 0 if $1 >= $2)
version_gte() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# Check if already set up and up to date
if [ -f "$VERSION_FILE" ] && [ "$FORCE" = false ]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
    if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
        echo -e "${GREEN}✓ Security setup is already installed and up to date (v$VERSION)${NC}"
        echo ""
        echo "To force re-run: setup-security --force"
        exit 0
    elif version_gte "$INSTALLED_VERSION" "$VERSION"; then
        echo -e "${GREEN}✓ Security setup is already installed with newer version (v$INSTALLED_VERSION)${NC}"
        echo ""
        echo "To force re-run: setup-security --force"
        exit 0
    else
        echo -e "${BLUE}Upgrading security setup from v$INSTALLED_VERSION to v$VERSION...${NC}"
        echo ""
    fi
fi

# Check for required tools
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed.${NC}"
        echo -e "${YELLOW}Install with: $2${NC}"
        exit 1
    else
        echo -e "${GREEN}✓${NC} $1 found"
    fi
}

echo "Checking dependencies..."
check_dependency "pre-commit" "brew install pre-commit"
check_dependency "trufflehog" "brew install trufflehog"
echo ""

# Create .security directory for auxiliary files
if [ ! -d "$SECURITY_DIR" ]; then
    mkdir -p "$SECURITY_DIR"
    echo -e "${GREEN}✓${NC} Created $SECURITY_DIR directory"
fi

# Define hook blocks as functions for reuse (used when merging into existing config)
get_precommit_hooks_block() {
    cat << 'HOOK_EOF'

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: check-added-large-files
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-merge-conflict
      - id: detect-private-key
HOOK_EOF
}

get_detect_secrets_block() {
    cat << 'HOOK_EOF'

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.security/secrets.baseline']
        exclude: '(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|\.security/secrets\.baseline)$'
HOOK_EOF
}

get_semgrep_block() {
    cat << 'HOOK_EOF'

  # Semgrep for additional security checks (catches secrets in seed scripts, etc.)
  - repo: https://github.com/returntocorp/semgrep
    rev: v1.73.0
    hooks:
      - id: semgrep
        args: ["--config", "p/ci", "--error", "--metrics=off"]
HOOK_EOF
}

get_trufflehog_block() {
    cat << 'HOOK_EOF'

  # Pre-push hook: comprehensive secret scan with verification
  - repo: local
    hooks:
      - id: trufflehog-filesystem
        name: trufflehog filesystem scan (no node_modules)
        entry: trufflehog filesystem . --no-update --exclude-paths .security/trufflehogignore
        language: system
        stages: [pre-push]
        pass_filenames: false
        always_run: true
HOOK_EOF
}

# Create or update .pre-commit-config.yaml (at root - standard location)
if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing $CONFIG_FILE - checking for missing hooks..."

    # Create backup
    BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓${NC} Created backup: $BACKUP_FILE"

    CONFIG_MODIFIED=false

    # Check and add default_stages if missing
    if ! grep -q "default_stages:" "$CONFIG_FILE"; then
        echo "  Adding default_stages: [pre-commit]..."
        # Prepend to file
        TMP_FILE=$(mktemp)
        echo "# Only run hooks on commit by default; trufflehog explicitly runs on pre-push" > "$TMP_FILE"
        echo "default_stages: [pre-commit]" >> "$TMP_FILE"
        echo "" >> "$TMP_FILE"
        cat "$CONFIG_FILE" >> "$TMP_FILE"
        mv "$TMP_FILE" "$CONFIG_FILE"
        CONFIG_MODIFIED=true
    else
        echo -e "  ${YELLOW}⚠${NC} default_stages already present"
    fi

    # Check and add pre-commit-hooks repo
    if ! grep -q "github.com/pre-commit/pre-commit-hooks" "$CONFIG_FILE"; then
        echo "  Adding pre-commit-hooks..."
        get_precommit_hooks_block >> "$CONFIG_FILE"
        CONFIG_MODIFIED=true
    else
        echo -e "  ${YELLOW}⚠${NC} pre-commit-hooks already present"
    fi

    # Check and add detect-secrets repo
    if ! grep -q "github.com/Yelp/detect-secrets" "$CONFIG_FILE"; then
        echo "  Adding detect-secrets..."
        get_detect_secrets_block >> "$CONFIG_FILE"
        CONFIG_MODIFIED=true
    else
        echo -e "  ${YELLOW}⚠${NC} detect-secrets already present"
    fi

    # Check and add semgrep repo
    if ! grep -q "github.com/returntocorp/semgrep" "$CONFIG_FILE"; then
        echo "  Adding semgrep..."
        get_semgrep_block >> "$CONFIG_FILE"
        CONFIG_MODIFIED=true
    else
        echo -e "  ${YELLOW}⚠${NC} semgrep already present"
    fi

    # Check and add trufflehog hook
    if ! grep -q "trufflehog-filesystem" "$CONFIG_FILE"; then
        echo "  Adding trufflehog pre-push hook..."
        get_trufflehog_block >> "$CONFIG_FILE"
        CONFIG_MODIFIED=true
    else
        echo -e "  ${YELLOW}⚠${NC} trufflehog-filesystem already present"
    fi

    if [ "$CONFIG_MODIFIED" = true ]; then
        echo ""
        echo -e "${GREEN}✓${NC} Updated $CONFIG_FILE"
        echo ""
        echo -e "${YELLOW}Changes made (diff):${NC}"
        diff "$BACKUP_FILE" "$CONFIG_FILE" || true
        echo ""
        echo -e "${YELLOW}Review the changes above. To revert:${NC}"
        echo "  mv $BACKUP_FILE $CONFIG_FILE"
    else
        echo -e "${GREEN}✓${NC} All security hooks already present"
        rm "$BACKUP_FILE"  # No changes needed, remove backup
    fi
else
    echo "Creating $CONFIG_FILE..."
    cat > "$CONFIG_FILE" << 'EOF'
# Only run hooks on commit by default; trufflehog explicitly runs on pre-push
default_stages: [pre-commit]

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: check-added-large-files
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.security/secrets.baseline']
        exclude: '(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|\.security/secrets\.baseline)$'

  # Semgrep for additional security checks (catches secrets in seed scripts, etc.)
  - repo: https://github.com/returntocorp/semgrep
    rev: v1.73.0
    hooks:
      - id: semgrep
        args: ["--config", "p/ci", "--error", "--metrics=off"]

  # Pre-push hook: comprehensive secret scan with verification
  - repo: local
    hooks:
      - id: trufflehog-filesystem
        name: trufflehog filesystem scan (no node_modules)
        entry: trufflehog filesystem . --no-update --exclude-paths .security/trufflehogignore
        language: system
        stages: [pre-push]
        pass_filenames: false
        always_run: true
EOF
    echo -e "${GREEN}✓${NC} Created $CONFIG_FILE"
fi

# Create or fix trufflehogignore (in .security/)
TRUFFLEHOG_IGNORE="$SECURITY_DIR/trufflehogignore"
write_trufflehogignore() {
    cat > "$TRUFFLEHOG_IGNORE" << 'EOF'
node_modules
dist
build
.next
coverage
.cache
EOF
}

if [ -f "$TRUFFLEHOG_IGNORE" ]; then
    # Check for invalid glob patterns that break trufflehog
    if grep -qE '^\*\*/' "$TRUFFLEHOG_IGNORE" || grep -qE '^\*\.' "$TRUFFLEHOG_IGNORE"; then
        echo -e "${YELLOW}⚠ $TRUFFLEHOG_IGNORE contains invalid glob patterns${NC}"
        BACKUP_FILE="$TRUFFLEHOG_IGNORE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$TRUFFLEHOG_IGNORE" "$BACKUP_FILE"
        echo -e "  ${GREEN}✓${NC} Backed up to: $BACKUP_FILE"
        write_trufflehogignore
        echo -e "  ${GREEN}✓${NC} Regenerated with valid patterns"
    else
        echo -e "${YELLOW}⚠ $TRUFFLEHOG_IGNORE already exists - skipping${NC}"
    fi
else
    echo "Creating $TRUFFLEHOG_IGNORE..."
    write_trufflehogignore
    echo -e "${GREEN}✓${NC} Created $TRUFFLEHOG_IGNORE"
fi

# Update .gitignore with sensitive directories
update_gitignore() {
    local entry="$1"
    if [ -f ".gitignore" ]; then
        if ! grep -qxF "$entry" .gitignore; then
            echo "$entry" >> .gitignore
            return 0  # Added
        fi
        return 1  # Already exists
    else
        echo "$entry" > .gitignore
        return 0  # Created and added
    fi
}

echo "Updating .gitignore..."
GITIGNORE_UPDATED=false

# Add Claude AI directories (can contain conversation history and sensitive context)
if ! grep -q "# Claude AI" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Claude AI" >> .gitignore
    GITIGNORE_UPDATED=true
fi
update_gitignore "/.claude" && GITIGNORE_UPDATED=true
update_gitignore ".claude" && GITIGNORE_UPDATED=true
update_gitignore "/.planning" && GITIGNORE_UPDATED=true
update_gitignore ".planning" && GITIGNORE_UPDATED=true

# Add other common sensitive files
if ! grep -q "# Environment files" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Environment files" >> .gitignore
    GITIGNORE_UPDATED=true
fi
update_gitignore ".env" && GITIGNORE_UPDATED=true
update_gitignore ".env.local" && GITIGNORE_UPDATED=true
update_gitignore ".env.*.local" && GITIGNORE_UPDATED=true

if [ "$GITIGNORE_UPDATED" = true ]; then
    echo -e "${GREEN}✓${NC} Updated .gitignore with sensitive directories"
else
    echo -e "${YELLOW}⚠${NC} .gitignore already contains all entries"
fi

# Create secrets baseline (in .security/)
BASELINE_FILE="$SECURITY_DIR/secrets.baseline"
if [ -f "$BASELINE_FILE" ]; then
    echo -e "${YELLOW}⚠ $BASELINE_FILE already exists - updating...${NC}"
fi
echo "Generating $BASELINE_FILE..."
detect-secrets scan --exclude-files '(pnpm-lock\.yaml|package-lock\.json|yarn\.lock)$' > "$BASELINE_FILE"
echo -e "${GREEN}✓${NC} Generated $BASELINE_FILE"

# Install pre-commit hooks
echo ""
echo "Installing pre-commit hooks..."
pre-commit install --hook-type pre-commit --hook-type pre-push
echo -e "${GREEN}✓${NC} Installed pre-commit and pre-push hooks"

# Write version file to track installation (in .security/)
echo "$VERSION" > "$VERSION_FILE"
echo -e "${GREEN}✓${NC} Recorded setup version ($VERSION)"

# Summary
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Setup Complete! (v$VERSION)${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Your project now has:"
echo "  - Pre-commit hooks: detect-secrets, detect-private-key, and more"
echo "  - Pre-push hooks: trufflehog with verified secret detection"
echo ""
echo "Files created/updated:"
echo "  - .pre-commit-config.yaml (hook configuration)"
echo "  - .security/trufflehogignore (paths to skip)"
echo "  - .security/secrets.baseline (detect-secrets baseline)"
echo "  - .security/version (tracks setup version)"
echo "  - .gitignore (added .claude, .planning, .env entries)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated files"
echo "  2. Add them to git: git add .pre-commit-config.yaml .security .gitignore"
echo "  3. Commit: git commit -m 'chore: add secret detection pipeline'"
echo ""
echo -e "${YELLOW}To test the hooks:${NC}"
echo "  - Commit hook: pre-commit run --all-files"
echo "  - Push hook: pre-commit run --hook-stage pre-push"
