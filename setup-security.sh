#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Secret Detection Pipeline Setup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not a git repository. Please run this from a git project root.${NC}"
    exit 1
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

get_trufflehog_block() {
    cat << 'HOOK_EOF'

  # Pre-push hook: comprehensive secret scan with verification
  - repo: local
    hooks:
      - id: trufflehog-filesystem
        name: trufflehog filesystem scan
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

  # Pre-push hook: comprehensive secret scan with verification
  - repo: local
    hooks:
      - id: trufflehog-filesystem
        name: trufflehog filesystem scan
        entry: trufflehog filesystem . --no-update --exclude-paths .trufflehogignore
        language: system
        stages: [pre-push]
        pass_filenames: false
        always_run: true
EOF
    echo -e "${GREEN}✓${NC} Created .pre-commit-config.yaml"
fi

# Create .trufflehogignore
if [ -f ".trufflehogignore" ]; then
    echo -e "${YELLOW}⚠ .trufflehogignore already exists - skipping${NC}"
else
    echo "Creating .trufflehogignore..."
    cat > .trufflehogignore << 'EOF'
# Dependencies
node_modules/
vendor/
.pnpm-store/

# Build outputs
dist/
build/
.next/
out/

# Lock files (contain package integrity hashes, not secrets)
pnpm-lock.yaml
package-lock.json
yarn.lock
composer.lock
Gemfile.lock
poetry.lock
Cargo.lock

# Git
.git/

# IDE
.idea/
.vscode/

# Test fixtures and snapshots
**/__snapshots__/
**/fixtures/
**/test-data/

# Generated files
*.min.js
*.min.css
*.map
EOF
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

# Summary
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
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
echo "  • .gitignore (added .claude, .planning, .env entries)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated files"
echo "  2. Add them to git: git add .pre-commit-config.yaml .trufflehogignore .secrets.baseline .gitignore"
echo "  3. Commit: git commit -m 'chore: add secret detection pipeline'"
echo ""
echo -e "${YELLOW}To test the hooks:${NC}"
echo "  • Commit hook: pre-commit run --all-files"
echo "  • Push hook: pre-commit run --hook-stage pre-push"
