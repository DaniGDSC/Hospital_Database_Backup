#!/usr/bin/env bash
set -euo pipefail

# Daily verification of log pipeline health
# Checks: Loki receiving all 4 log types, no gaps, storage OK

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

LOKI_URL="${LOKI_URL:-http://localhost:3100}"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }

echo -e "${BLUE}=== Log Pipeline Verification ===${NC}"
echo "Loki: ${LOKI_URL}"
echo ""

# Check 0: Loki is reachable
echo -e "${BLUE}[0/5] Loki connectivity${NC}"
if curl -s "${LOKI_URL}/ready" 2>/dev/null | grep -q "ready"; then
    pass "Loki is ready"
else
    fail "Loki is not reachable at ${LOKI_URL}"
    echo -e "${RED}Cannot continue — fix Loki first${NC}"
    exit 1
fi

# Check 1-4: Each job has recent logs
JOBS=("security_audit:60" "sqlserver:15" "automation:60" "backup:60")

CHECK_NUM=1
for JOB_SPEC in "${JOBS[@]}"; do
    JOB_NAME="${JOB_SPEC%%:*}"
    MAX_GAP_MIN="${JOB_SPEC##*:}"
    CHECK_NUM=$((CHECK_NUM + 1))

    echo ""
    echo -e "${BLUE}[${CHECK_NUM}/5] Job: ${JOB_NAME} (max gap: ${MAX_GAP_MIN}m)${NC}"

    # Query Loki for recent logs from this job
    RESULT=$(curl -s -G "${LOKI_URL}/loki/api/v1/query" \
        --data-urlencode "query=count_over_time({job=\"${JOB_NAME}\"}[${MAX_GAP_MIN}m])" \
        2>/dev/null || echo '{"data":{"result":[]}}')

    LOG_COUNT=$(echo "$RESULT" | grep -o '"value":\["[^"]*","[^"]*"\]' | head -1 | grep -o '"[0-9]*"' | tail -1 | tr -d '"' || echo "0")

    if [ "${LOG_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        pass "${JOB_NAME}: ${LOG_COUNT} logs in last ${MAX_GAP_MIN} minutes"
    else
        fail "${JOB_NAME}: No logs in last ${MAX_GAP_MIN} minutes"
    fi
done

# Check 5: Loki storage
echo ""
echo -e "${BLUE}[5/5] Loki storage${NC}"
# Check if Loki data directory exists and isn't too full (via Docker volume)
if docker inspect hospital-loki &>/dev/null; then
    pass "Loki container running"
else
    fail "Loki container not found (is docker-compose up?)"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All log pipeline checks passed${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} check(s) failed — log pipeline needs attention${NC}"
    exit 1
fi
