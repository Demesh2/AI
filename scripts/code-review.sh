#!/usr/bin/env bash
# code-review.sh — Automated code review checks for staged/changed files
# Part of code-review@claude-plugins-official

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

ISSUES=0
WARNINGS=0

echo "========================================="
echo "  Code Review Plugin - Automated Checks"
echo "========================================="
echo ""

# Get list of changed files (staged or modified)
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [ -z "$CHANGED_FILES" ]; then
    echo -e "${GREEN}No changed files to review.${NC}"
    exit 0
fi

echo "Reviewing changed files:"
echo "$CHANGED_FILES" | sed 's/^/  - /'
echo ""

for file in $CHANGED_FILES; do
    # Skip if file doesn't exist (deleted)
    [ -f "$file" ] || continue

    echo "--- Reviewing: $file ---"

    # Check 1: Large files (> 500 lines changed)
    LINE_COUNT=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [ "$LINE_COUNT" -gt 500 ]; then
        echo -e "  ${YELLOW}[WARNING] File has $LINE_COUNT lines — consider splitting into smaller modules${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check 2: Detect common secrets/credentials patterns
    if grep -qEin '(password|secret|api_key|apikey|access_token|private_key)\s*[:=]\s*["\x27][^\s]+' "$file" 2>/dev/null; then
        echo -e "  ${RED}[ISSUE] Possible hardcoded secret or credential detected${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    # Check 3: Detect TODO/FIXME/HACK comments
    TODO_COUNT=$(grep -ciE '(TODO|FIXME|HACK|XXX):' "$file" 2>/dev/null || echo 0)
    if [ "$TODO_COUNT" -gt 0 ]; then
        echo -e "  ${YELLOW}[WARNING] Found $TODO_COUNT TODO/FIXME/HACK comments${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check 4: Trailing whitespace
    if grep -qP '\s+$' "$file" 2>/dev/null; then
        echo -e "  ${YELLOW}[WARNING] Trailing whitespace detected${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check 5: Detect debug/console statements in code files
    case "$file" in
        *.js|*.ts|*.jsx|*.tsx)
            if grep -qE 'console\.(log|debug|info)\(' "$file" 2>/dev/null; then
                echo -e "  ${YELLOW}[WARNING] console.log/debug statements found — remove before merging${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
            ;;
        *.py)
            if grep -qE '^\s*(print\(|breakpoint\(\)|import pdb)' "$file" 2>/dev/null; then
                echo -e "  ${YELLOW}[WARNING] Debug print/breakpoint statements found${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
            ;;
        *.rb)
            if grep -qE '(puts |binding\.pry|byebug)' "$file" 2>/dev/null; then
                echo -e "  ${YELLOW}[WARNING] Debug statements found (puts/pry/byebug)${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
            ;;
    esac

    # Check 6: Detect large functions (rough heuristic for common languages)
    case "$file" in
        *.js|*.ts|*.jsx|*.tsx|*.java|*.go|*.rs)
            # Count consecutive non-empty lines as a rough function-length proxy
            LONGEST_BLOCK=$(awk 'NF{c++; if(c>m) m=c; next} {c=0} END{print m+0}' "$file" 2>/dev/null || echo 0)
            if [ "$LONGEST_BLOCK" -gt 100 ]; then
                echo -e "  ${YELLOW}[WARNING] Contains a code block of $LONGEST_BLOCK lines — consider refactoring${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
            ;;
        *.py)
            LONGEST_BLOCK=$(awk 'NF{c++; if(c>m) m=c; next} {c=0} END{print m+0}' "$file" 2>/dev/null || echo 0)
            if [ "$LONGEST_BLOCK" -gt 80 ]; then
                echo -e "  ${YELLOW}[WARNING] Contains a code block of $LONGEST_BLOCK lines — consider refactoring${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
            ;;
    esac

done

echo ""
echo "========================================="
echo "  Review Summary"
echo "========================================="
echo -e "  Issues:   ${RED}$ISSUES${NC}"
echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ "$ISSUES" -gt 0 ]; then
    echo -e "${RED}Code review found $ISSUES issue(s) that should be addressed.${NC}"
    exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}Code review found $WARNINGS warning(s) — please review before merging.${NC}"
    exit 0
fi

echo -e "${GREEN}All automated checks passed!${NC}"
exit 0
