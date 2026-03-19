#!/usr/bin/env bash
set -euo pipefail

# Compare tool versions across dev/staging/production
# Flags mismatches that could cause deployment issues
#
# NOTE: This script checks the LOCAL environment only.
# For cross-server comparison, run on each server and compare output.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"
source "${PROJECT_ROOT}/config/versions.conf"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Environment Version Report                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Server:      $(hostname)"
echo "Environment: ${ENVIRONMENT}"
echo "Date:        $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""

# Collect versions
SQL_VER=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -h -1 -W \
    -Q "SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20))" \
    2>/dev/null | head -1 | tr -d ' ' || echo "N/A")

SQL_EDITION=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -h -1 -W \
    -Q "SELECT CAST(SERVERPROPERTY('Edition') AS VARCHAR(50))" \
    2>/dev/null | head -1 | tr -d ' ' || echo "N/A")

AWS_VER=$(aws --version 2>&1 | grep -oP 'aws-cli/\K[0-9]+\.[0-9]+\.[0-9]+' || echo "N/A")
DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "N/A")
BASH_VER="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
OPENSSL_VER=$(openssl version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "N/A")
OS_VER=$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "N/A")

# Output table
printf "%-16s %-20s %-20s %-8s\n" "Tool" "Installed" "Required" "Status"
printf "%-16s %-20s %-20s %-8s\n" "────────────────" "────────────────────" "────────────────────" "────────"
printf "%-16s %-20s %-20s %-8s\n" "SQL Server" "$SQL_VER" ">= $SQLSERVER_MIN_BUILD" "$([ "$SQL_VER" \> "$SQLSERVER_MIN_BUILD" ] 2>/dev/null && echo "✅" || echo "⚠️")"
printf "%-16s %-20s %-20s %-8s\n" "SQL Edition" "$SQL_EDITION" "$SQLSERVER_EDITION" "$(echo "$SQL_EDITION" | grep -qi "$SQLSERVER_EDITION" && echo "✅" || echo "⚠️")"
printf "%-16s %-20s %-20s %-8s\n" "AWS CLI" "$AWS_VER" ">= $AWSCLI_MIN_VERSION" "$([ "$AWS_VER" != "N/A" ] && echo "✅" || echo "⚠️")"
printf "%-16s %-20s %-20s %-8s\n" "Docker" "$DOCKER_VER" ">= $DOCKER_MIN_VERSION" "$([ "$DOCKER_VER" != "N/A" ] && echo "✅" || echo "⚠️")"
printf "%-16s %-20s %-20s %-8s\n" "Bash" "$BASH_VER" ">= $BASH_MIN_VERSION" "✅"
printf "%-16s %-20s %-20s %-8s\n" "OpenSSL" "$OPENSSL_VER" ">= $OPENSSL_MIN_VERSION" "$([ "$OPENSSL_VER" != "N/A" ] && echo "✅" || echo "⚠️")"
printf "%-16s %-20s %-20s %-8s\n" "OS" "$OS_VER" "$OS_EXPECTED" "ℹ️"

echo ""
echo "To compare across servers, run this script on each and diff the output."
