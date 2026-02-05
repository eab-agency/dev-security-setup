#!/bin/bash
set -e

# Version of this setup script - increment when making changes
VERSION="1.2.0"
VERSION_FILE=".security-setup-version"

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

# Define hook blocks as functions for reuse
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
        args: ['--baseline', '.secrets.baseline']
        exclude: '(pnpm-lock\.yaml|package-lock\.json|yarn\.lock)$'
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
        entry: trufflehog filesystem . --no-update --exclude-paths .trufflehogignore
        language: system
        stages: [pre-push]
        pass_filenames: false
        always_run: true
HOOK_EOF
}

# Create or update .pre-commit-config.yaml
if [ -f ".pre-commit-config.yaml" ]; then
    echo "Found existing .pre-commit-config.yaml - checking for missing hooks..."

    # Create backup
    BACKUP_FILE=".pre-commit-config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
    cp .pre-commit-config.yaml "$BACKUP_FILE"
    echo -e "${GREEN}✓${NC} Created backup: $BACKUP_FILE"

    HOOKS_ADDED=false

    # Check and add pre-commit-hooks repo
    if ! grep -q "github.com/pre-commit/pre-commit-hooks" .pre-commit-config.yaml; then
        echo "  Adding pre-commit-hooks..."
        get_precommit_hooks_block >> .pre-commit-config.yaml
        HOOKS_ADDED=true
    else
        echo -e "  ${YELLOW}⚠${NC} pre-commit-hooks already present"
    fi

    # Check and add detect-secrets repo
    if ! grep -q "github.com/Yelp/detect-secrets" .pre-commit-config.yaml; then
        echo "  Adding detect-secrets..."
        get_detect_secrets_block >> .pre-commit-config.yaml
        HOOKS_ADDED=true
    else
        echo -e "  ${YELLOW}⚠${NC} detect-secrets already present"
    fi

    # Check and add semgrep repo
    if ! grep -q "github.com/returntocorp/semgrep" .pre-commit-config.yaml; then
        echo "  Adding semgrep..."
        get_semgrep_block >> .pre-commit-config.yaml
        HOOKS_ADDED=true
    else
        echo -e "  ${YELLOW}⚠${NC} semgrep already present"
    fi

    # Check and add trufflehog hook
    if ! grep -q "trufflehog-filesystem" .pre-commit-config.yaml; then
        echo "  Adding trufflehog pre-push hook..."
        get_trufflehog_block >> .pre-commit-config.yaml
        HOOKS_ADDED=true
    else
        echo -e "  ${YELLOW}⚠${NC} trufflehog-filesystem already present"
    fi

    if [ "$HOOKS_ADDED" = true ]; then
        echo ""
        echo -e "${GREEN}✓${NC} Updated .pre-commit-config.yaml"
        echo ""
        echo -e "${YELLOW}Changes made (diff):${NC}"
        diff "$BACKUP_FILE" .pre-commit-config.yaml || true
        echo ""
        echo -e "${YELLOW}Review the changes above. To revert:${NC}"
        echo "  mv $BACKUP_FILE .pre-commit-config.yaml"
    else
        echo -e "${GREEN}✓${NC} All security hooks already present"
        rm "$BACKUP_FILE"  # No changes needed, remove backup
    fi
else
    echo "Creating .pre-commit-config.yaml..."
    cat > .pre-commit-config.yaml << 'EOF'
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
        args: ['--baseline', '.secrets.baseline']
        exclude: '(pnpm-lock\.yaml|package-lock\.json|yarn\.lock)$'

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
        entry: trufflehog filesystem . --no-update --exclude-paths .trufflehogignore
        language: system
        stages: [pre-push]
        pass_filenames: false
        always_run: true
EOF
    echo -e "${GREEN}✓${NC} Created .pre-commit-config.yaml"
fi

# Create or fix .trufflehogignore
# Note: trufflehog exclude-paths uses simple path matching
write_trufflehogignore() {
    cat > .trufflehogignore << 'EOF'
node_modules
dist
build
.next
coverage
.cache
EOF
}

if [ -f ".trufflehogignore" ]; then
    # Check for invalid glob patterns that break trufflehog
    if grep -qE '^\*\*/' .trufflehogignore || grep -qE '^\*\.' .trufflehogignore; then
        echo -e "${YELLOW}⚠ .trufflehogignore contains invalid glob patterns (trufflehog uses regex)${NC}"
        BACKUP_FILE=".trufflehogignore.backup.$(date +%Y%m%d_%H%M%S)"
        cp .trufflehogignore "$BACKUP_FILE"
        echo -e "  ${GREEN}✓${NC} Backed up to: $BACKUP_FILE"
        write_trufflehogignore
        echo -e "  ${GREEN}✓${NC} Regenerated .trufflehogignore with valid regex patterns"
    else
        echo -e "${YELLOW}⚠ .trufflehogignore already exists - skipping${NC}"
    fi
else
    echo "Creating .trufflehogignore..."
    write_trufflehogignore
    echo -e "${GREEN}✓${NC} Created .trufflehogignore"
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

# Create .secrets.baseline
if [ -f ".secrets.baseline" ]; then
    echo -e "${YELLOW}⚠ .secrets.baseline already exists - updating...${NC}"
fi
echo "Generating .secrets.baseline..."
detect-secrets scan --exclude-files '(pnpm-lock\.yaml|package-lock\.json|yarn\.lock)$' > .secrets.baseline
echo -e "${GREEN}✓${NC} Generated .secrets.baseline"

# Install pre-commit hooks
echo ""
echo "Installing pre-commit hooks..."
pre-commit install --hook-type pre-commit --hook-type pre-push
echo -e "${GREEN}✓${NC} Installed pre-commit and pre-push hooks"

# Write version file to track installation
echo "$VERSION" > "$VERSION_FILE"
echo -e "${GREEN}✓${NC} Recorded setup version ($VERSION)"

# Summary
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Setup Complete! (v$VERSION)${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Your project now has:"
echo "  • Pre-commit hooks: detect-secrets, detect-private-key, and more"
echo "  • Pre-push hooks: trufflehog with verified secret detection"
echo ""
echo "Files created/updated:"
echo "  • .pre-commit-config.yaml"
echo "  • .trufflehogignore"
echo "  • .secrets.baseline"
echo "  • .security-setup-version"
echo "  • .gitignore (added .claude, .planning, .env entries)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated files"
echo "  2. Add them to git: git add .pre-commit-config.yaml .trufflehogignore .secrets.baseline .security-setup-version .gitignore"
echo "  3. Commit: git commit -m 'chore: add secret detection pipeline'"
echo ""
echo -e "${YELLOW}To test the hooks:${NC}"
echo "  • Commit hook: pre-commit run --all-files"
echo "  • Push hook: pre-commit run --hook-stage pre-push"
