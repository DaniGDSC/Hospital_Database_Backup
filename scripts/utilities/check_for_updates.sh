#!/usr/bin/env bash
set -euo pipefail

# Monthly update availability check
# Compares installed versions against latest available
# Does NOT install anything — report only

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"
source "${PROJECT_ROOT}/config/versions.conf"

echo -e "${BLUE}=== Monthly Update Availability Check ===${NC}"
echo "Date: $(date -u '+%Y-%m-%d')"
echo ""

# AWS CLI
echo -e "${BLUE}[1/4] AWS CLI${NC}"
CURRENT_AWS=$(aws --version 2>&1 | grep -oP 'aws-cli/\K[0-9]+\.[0-9]+\.[0-9]+' || echo "not installed")
echo "  Installed: ${CURRENT_AWS}"
echo "  Pinned:    ${AWSCLI_PINNED_VERSION}"
if [ "$CURRENT_AWS" != "$AWSCLI_PINNED_VERSION" ] && [ -n "$AWSCLI_PINNED_VERSION" ]; then
    echo -e "  ${YELLOW}UPDATE AVAILABLE${NC}"
else
    echo -e "  ${GREEN}UP TO DATE${NC}"
fi

# SQL Server
echo ""
echo -e "${BLUE}[2/4] SQL Server${NC}"
SQL_BUILD=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -h -1 -W \
    -Q "SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20))" \
    2>/dev/null | head -1 | tr -d ' ' || echo "unavailable")
echo "  Installed: ${SQL_BUILD}"
echo "  Min build: ${SQLSERVER_MIN_BUILD}"
echo "  Check: https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/build-versions"

# Docker
echo ""
echo -e "${BLUE}[3/4] Docker${NC}"
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    echo "  Installed: ${DOCKER_VER}"
    echo "  Min:       ${DOCKER_MIN_VERSION}"
else
    echo "  Not installed"
fi

# OpenSSL
echo ""
echo -e "${BLUE}[4/4] OpenSSL${NC}"
OPENSSL_VER=$(openssl version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
echo "  Installed: ${OPENSSL_VER}"
echo "  Min:       ${OPENSSL_MIN_VERSION}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo "Review updates and test on dev before promoting."
echo "See: docs/PATCHING_SCHEDULE.md"
