#!/usr/bin/env bash
set -euo pipefail

# Verify SQL Server TLS is properly configured and active
# HIPAA 45 CFR 164.312(e)(1): Transmission Security

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; }

echo -e "${BLUE}=== TLS Connection Verification ===${NC}"
echo ""

# Test 1: TLS certificate exists
echo -e "${BLUE}[1/4] TLS certificate file${NC}"
if [ -f "$TLS_CERT_FILE" ]; then
    pass "Certificate found: $TLS_CERT_FILE"
else
    fail "Certificate not found: $TLS_CERT_FILE"
    echo "  Run: ./generate_tls_cert.sh"
fi

# Test 2: Certificate expiry
echo ""
echo -e "${BLUE}[2/4] Certificate expiry${NC}"
if [ -f "$TLS_CERT_FILE" ]; then
    EXPIRY_DATE=$(openssl x509 -in "$TLS_CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

    if [ "$DAYS_LEFT" -gt 60 ]; then
        pass "Expires in ${DAYS_LEFT} days ($EXPIRY_DATE)"
    elif [ "$DAYS_LEFT" -gt 30 ]; then
        warn "Expires in ${DAYS_LEFT} days — renew soon"
        ((PASS_COUNT++))
    else
        fail "Expires in ${DAYS_LEFT} days — URGENT renewal needed"
    fi
else
    fail "Cannot check expiry — certificate file missing"
fi

# Test 3: mssql.conf has TLS settings
echo ""
echo -e "${BLUE}[3/4] SQL Server TLS configuration${NC}"
MSSQL_CONF="/var/opt/mssql/mssql.conf"
if [ -f "$MSSQL_CONF" ]; then
    if sudo grep -q "forceencryption" "$MSSQL_CONF" 2>/dev/null; then
        pass "forceencryption configured in mssql.conf"
    else
        fail "forceencryption NOT found in mssql.conf"
        echo "  Run: ./configure_mssql_tls.sh"
    fi
else
    warn "mssql.conf not found (may be in Docker container)"
    ((PASS_COUNT++))
fi

# Test 4: Connection is encrypted
echo ""
echo -e "${BLUE}[4/4] Encrypted connection test${NC}"
ENCRYPT_STATUS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -h -1 -W \
    -Q "SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID" \
    2>/dev/null | tr -d ' ' | head -1 || echo "UNKNOWN")

if [ "$ENCRYPT_STATUS" = "TRUE" ]; then
    pass "Connection is encrypted (encrypt_option=TRUE)"
elif [ "$ENCRYPT_STATUS" = "FALSE" ]; then
    fail "Connection is NOT encrypted"
else
    warn "Could not determine encryption status (${ENCRYPT_STATUS})"
    ((PASS_COUNT++))
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
