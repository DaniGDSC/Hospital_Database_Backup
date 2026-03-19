#!/usr/bin/env bash
set -euo pipefail

# Pre-deployment secrets validation
# Checks: all vars set, minimum length, no reuse, .env not in git

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
MIN_LENGTH=16

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; ((WARN_COUNT++)); }

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Secrets Validation Report                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check 1: All required variables are set
echo -e "${BLUE}[1/4] Required Variables${NC}"
REQUIRED_VARS=(
    SQL_PASSWORD
    MASTER_KEY_PASSWORD
    CERT_BACKUP_PASSWORD
    APP_RW_PASSWORD
    APP_RO_PASSWORD
    APP_BILLING_PASSWORD
    APP_AUDIT_PASSWORD
)

for var_name in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        fail "${var_name} is not set"
    else
        pass "${var_name} is set"
    fi
done
echo ""

# Check 2: Minimum password length
echo -e "${BLUE}[2/4] Password Length (minimum ${MIN_LENGTH} characters)${NC}"
for var_name in "${REQUIRED_VARS[@]}"; do
    val="${!var_name:-}"
    if [ -n "$val" ]; then
        if [ ${#val} -ge $MIN_LENGTH ]; then
            pass "${var_name} length OK (${#val} chars)"
        else
            fail "${var_name} too short (${#val} chars, need ${MIN_LENGTH})"
        fi
    fi
done
echo ""

# Check 3: No password reuse
echo -e "${BLUE}[3/4] Password Uniqueness (no reuse)${NC}"
declare -A seen_passwords
REUSE_FOUND=0
for var_name in "${REQUIRED_VARS[@]}"; do
    val="${!var_name:-}"
    if [ -z "$val" ]; then continue; fi

    for other_var in "${REQUIRED_VARS[@]}"; do
        if [ "$var_name" = "$other_var" ]; then continue; fi
        other_val="${!other_var:-}"
        if [ "$val" = "$other_val" ]; then
            fail "${var_name} and ${other_var} use the same password"
            REUSE_FOUND=1
            break
        fi
    done

    if [ $REUSE_FOUND -eq 0 ]; then
        pass "${var_name} is unique"
    fi
    REUSE_FOUND=0
done
echo ""

# Check 4: .env is NOT committed to Git
echo -e "${BLUE}[4/4] Git Safety${NC}"
if [ -d "${PROJECT_ROOT}/.git" ]; then
    if git -C "$PROJECT_ROOT" ls-files --cached .env 2>/dev/null | grep -q ".env"; then
        fail ".env is tracked by Git — run: git rm --cached .env"
    else
        pass ".env is NOT tracked by Git"
    fi

    if git -C "$PROJECT_ROOT" ls-files --cached config/project.conf 2>/dev/null | grep -q "project.conf"; then
        fail "config/project.conf is tracked by Git — run: git rm --cached config/project.conf"
    else
        pass "config/project.conf is NOT tracked by Git"
    fi
else
    warn "Not a git repository — cannot verify .gitignore enforcement"
fi

if grep -q "^\.env$" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
    pass ".env is listed in .gitignore"
else
    fail ".env is NOT listed in .gitignore"
fi

if grep -q "^config/project.conf$" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
    pass "config/project.conf is listed in .gitignore"
else
    fail "config/project.conf is NOT listed in .gitignore"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "  ${YELLOW}WARN${NC}: ${WARN_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All secrets validation checks passed${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} check(s) failed — fix before deploying${NC}"
    exit 1
fi
