#!/usr/bin/env bash
set -euo pipefail

# Daily alert channel verification
# Checks: Telegram delivery, Grafana alerting active, Database Mail
# Run via cron: 0 8 * * * /path/to/check_alert_health.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }

echo -e "${BLUE}=== Alert Channel Health Check ===${NC}"
echo ""

# Check 1: Telegram
echo -e "${BLUE}[1/3] Telegram${NC}"
"${SCRIPT_DIR}/send_telegram.sh" "INFO" "Health Check" "Daily alert channel verification" 2>/dev/null
sleep 3
if tail -1 "${PROJECT_ROOT}/logs/telegram.log" 2>/dev/null | grep -q "SENT"; then
    pass "Telegram delivery confirmed"
else
    fail "Telegram delivery not confirmed"
fi

# Check 2: Grafana
echo ""
echo -e "${BLUE}[2/3] Grafana Alerting${NC}"
if curl -s "http://localhost:3000/api/health" 2>/dev/null | grep -q "ok"; then
    pass "Grafana is healthy"
else
    fail "Grafana not reachable"
fi

# Check 3: Database Mail
echo ""
echo -e "${BLUE}[3/3] Database Mail${NC}"
MAIL_STATUS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
    -h -1 -Q "SELECT CASE WHEN EXISTS(SELECT 1 FROM msdb.dbo.sysmail_profile) THEN 'OK' ELSE 'NO_PROFILE' END" \
    2>/dev/null | tr -d ' ' || echo "UNREACHABLE")
if [ "$MAIL_STATUS" = "OK" ]; then
    pass "Database Mail profile exists"
else
    fail "Database Mail: ${MAIL_STATUS}"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    "${SCRIPT_DIR}/send_telegram.sh" "WARNING" "Alert Health Check" "${FAIL_COUNT} alert channel(s) unhealthy"
fi

exit 0
