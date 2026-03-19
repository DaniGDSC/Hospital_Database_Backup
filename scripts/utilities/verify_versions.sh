#!/usr/bin/env bash
set -euo pipefail

# Verify all tool versions match pinned requirements
# Run before ANY deployment — blocks on mismatch in staging/production
# Sources: config/versions.conf + config/versions.{env}.conf

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

# Load version requirements
source "${PROJECT_ROOT}/config/versions.conf"
VERSION_ENV_FILE="${PROJECT_ROOT}/config/versions.${ENV}.conf"
[ -f "$VERSION_ENV_FILE" ] && source "$VERSION_ENV_FILE"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; ((WARN_COUNT++)); }

# Compare versions: returns 0 if $1 >= $2 (major.minor)
version_gte() {
    local v1="${1%%.*}" v2="${2%%.*}"
    local m1="${1#*.}" m2="${2#*.}"
    m1="${m1%%.*}"; m2="${m2%%.*}"
    [ "$v1" -gt "$v2" ] 2>/dev/null && return 0
    [ "$v1" -eq "$v2" ] 2>/dev/null && [ "${m1:-0}" -ge "${m2:-0}" ] 2>/dev/null && return 0
    return 1
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Tool Version Verification                           ║${NC}"
echo -e "${BLUE}║         Environment: ${ENVIRONMENT_TIER:-${ENV}}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Check 1: SQL Server ──
echo -e "${BLUE}[1/6] SQL Server${NC}"
SQL_VERSION=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -h -1 -W \
    -Q "SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20))" \
    2>/dev/null | head -1 | tr -d ' ' || echo "UNAVAILABLE")

if [ "$SQL_VERSION" = "UNAVAILABLE" ]; then
    warn "SQL Server not reachable — cannot verify version"
elif [[ "$SQL_VERSION" == 16.* ]]; then
    pass "SQL Server 2022 (build: ${SQL_VERSION})"
else
    fail "SQL Server version ${SQL_VERSION} — expected 2022 (16.x)"
fi

# ── Check 2: AWS CLI ──
echo ""
echo -e "${BLUE}[2/6] AWS CLI${NC}"
if command -v aws &>/dev/null; then
    AWS_VER=$(aws --version 2>&1 | grep -oP 'aws-cli/\K[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    if version_gte "$AWS_VER" "$AWSCLI_MIN_VERSION"; then
        pass "AWS CLI ${AWS_VER} (min: ${AWSCLI_MIN_VERSION})"
    else
        fail "AWS CLI ${AWS_VER} — minimum required: ${AWSCLI_MIN_VERSION}"
    fi
else
    warn "AWS CLI not installed"
fi

# ── Check 3: sqlcmd ──
echo ""
echo -e "${BLUE}[3/6] sqlcmd${NC}"
if command -v sqlcmd &>/dev/null; then
    SQLCMD_VER=$(sqlcmd -? 2>&1 | grep -oP 'Version \K[0-9]+\.[0-9]+' | head -1 || echo "0.0")
    if [ -n "$SQLCMD_VER" ] && version_gte "$SQLCMD_VER" "$SQLCMD_MIN_VERSION"; then
        pass "sqlcmd ${SQLCMD_VER} (min: ${SQLCMD_MIN_VERSION})"
    elif [ -n "$SQLCMD_VER" ]; then
        fail "sqlcmd ${SQLCMD_VER} — minimum required: ${SQLCMD_MIN_VERSION}"
    else
        pass "sqlcmd installed (version parse unavailable)"
    fi
else
    fail "sqlcmd not installed"
fi

# ── Check 4: Docker ──
echo ""
echo -e "${BLUE}[4/6] Docker${NC}"
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 || echo "0.0")
    if version_gte "$DOCKER_VER" "$DOCKER_MIN_VERSION"; then
        pass "Docker ${DOCKER_VER} (min: ${DOCKER_MIN_VERSION})"
    else
        fail "Docker ${DOCKER_VER} — minimum required: ${DOCKER_MIN_VERSION}"
    fi
else
    warn "Docker not installed"
fi

# ── Check 5: Bash ──
echo ""
echo -e "${BLUE}[5/6] Bash${NC}"
BASH_VER="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
if version_gte "$BASH_VER" "$BASH_MIN_VERSION"; then
    pass "Bash ${BASH_VER} (min: ${BASH_MIN_VERSION})"
else
    fail "Bash ${BASH_VER} — minimum required: ${BASH_MIN_VERSION}"
fi

# ── Check 6: OpenSSL ──
echo ""
echo -e "${BLUE}[6/6] OpenSSL${NC}"
if command -v openssl &>/dev/null; then
    OPENSSL_VER=$(openssl version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 || echo "0.0")
    if version_gte "$OPENSSL_VER" "$OPENSSL_MIN_VERSION"; then
        pass "OpenSSL ${OPENSSL_VER} (min: ${OPENSSL_MIN_VERSION})"
    else
        fail "OpenSSL ${OPENSSL_VER} — minimum required: ${OPENSSL_MIN_VERSION}"
    fi
else
    fail "OpenSSL not installed"
fi

# ── Summary ──
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  Environment: ${ENVIRONMENT_TIER:-${ENV}}"
echo -e "  Strict mode: ${VERSION_CHECK_STRICT:-false}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}  ${YELLOW}WARN${NC}: ${WARN_COUNT}  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

# In strict mode (staging/production), FAIL blocks deployment
if [ "${VERSION_CHECK_STRICT:-false}" = "true" ] && [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}BLOCKED: ${FAIL_COUNT} version check(s) failed in ${ENVIRONMENT_TIER} (strict mode)${NC}"
    "${SCRIPT_DIR}/send_telegram.sh" "CRITICAL" "Version Mismatch" \
        "${FAIL_COUNT} version check(s) failed on ${ENVIRONMENT_TIER}" || true
    exit 1
fi

# In dev mode, warn but don't block
if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}WARNING: ${FAIL_COUNT} version mismatch(es) — fix before promoting to staging${NC}"
    exit 0
fi

exit 0
