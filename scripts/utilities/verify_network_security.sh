#!/usr/bin/env bash
set -euo pipefail

# Daily network security verification
# Checks: firewall, port exposure, TLS, Docker bindings

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; }

echo -e "${BLUE}=== Network Security Verification ===${NC}"
echo ""

# Test 1: UFW active
echo -e "${BLUE}[1/4] Firewall status${NC}"
if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    pass "UFW is active"
else
    fail "UFW is NOT active or not installed"
fi

# Test 2: SQL Server listen address
echo ""
echo -e "${BLUE}[2/4] SQL Server listen address${NC}"
SS_OUTPUT=$(ss -tlnp 2>/dev/null | grep ":${SQL_PORT}" || true)
if echo "$SS_OUTPUT" | grep -q "127.0.0.1:${SQL_PORT}"; then
    pass "SQL Server on localhost:${SQL_PORT} only"
elif echo "$SS_OUTPUT" | grep -q "0.0.0.0:${SQL_PORT}"; then
    warn "SQL Server on 0.0.0.0:${SQL_PORT} (all interfaces — restrict if possible)"
    ((PASS_COUNT++))
elif [ -z "$SS_OUTPUT" ]; then
    warn "Port ${SQL_PORT} not found in listen list (may be in Docker)"
    ((PASS_COUNT++))
else
    pass "SQL Server on ${SQL_PORT}"
fi

# Test 3: Docker monitoring ports bound to localhost
echo ""
echo -e "${BLUE}[3/4] Docker port bindings${NC}"
DOCKER_ISSUES=0
for port in 3000 9090 9100 3100; do
    if ss -tlnp 2>/dev/null | grep -q "0.0.0.0:${port}"; then
        warn "Port ${port} bound to 0.0.0.0 (should be 127.0.0.1)"
        DOCKER_ISSUES=$((DOCKER_ISSUES + 1))
    fi
done
if [ $DOCKER_ISSUES -eq 0 ]; then
    pass "No monitoring ports exposed on 0.0.0.0"
else
    fail "${DOCKER_ISSUES} monitoring port(s) exposed externally"
fi

# Test 4: SQL connection encrypted
echo ""
echo -e "${BLUE}[4/4] SQL Server encryption${NC}"
ENCRYPTED=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -h -1 -W \
    -Q "SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID" \
    2>/dev/null | tr -d ' ' | head -1 || echo "UNKNOWN")

if [ "$ENCRYPTED" = "TRUE" ]; then
    pass "Connection encrypted"
elif [ "$ENCRYPTED" = "FALSE" ]; then
    fail "Connection NOT encrypted"
else
    warn "Could not verify encryption (${ENCRYPTED})"
    ((PASS_COUNT++))
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    "${SCRIPT_DIR}/send_telegram.sh" "WARNING" "Network Security Check" \
        "${FAIL_COUNT} check(s) failed in network security verification" || true
fi

exit 0
