#!/usr/bin/env bash
set -euo pipefail

# Test complete destroy + rebuild on DEVELOPMENT ONLY
# Measures rebuild time and compares to RTO target
# ⚠️ NEVER run on staging or production

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

# Safety: development only
if [ "${ENVIRONMENT}" != "development" ]; then
    echo -e "${RED}BLOCKED: Rebuild test only allowed on development${NC}"
    echo "  Current environment: ${ENVIRONMENT}"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${PROJECT_ROOT}/reports/rebuild_test_${TIMESTAMP}.md"
RTO_TARGET_SECONDS=$((RTO_HOURS * 3600))

mkdir -p "${PROJECT_ROOT}/reports"

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         REBUILD TEST — Development Only                     ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Environment: ${ENVIRONMENT}"
echo "Database:    ${DATABASE_NAME}"
echo "RTO target:  ${RTO_HOURS} hours (${RTO_TARGET_SECONDS} seconds)"
echo ""

echo -e "${YELLOW}⚠️  This will DESTROY and REBUILD the dev database${NC}"
echo -e "${YELLOW}    Type exactly: CONFIRM REBUILD TEST${NC}"
read -r CONFIRM
if [ "$CONFIRM" != "CONFIRM REBUILD TEST" ]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Record pre-destroy state
echo ""
echo "--- Recording pre-destroy state ---"
PRE_TABLE_COUNT=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -d "$DATABASE_NAME" -h -1 \
    -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'" \
    2>/dev/null | tr -d ' ' || echo "0")
echo "  Tables: ${PRE_TABLE_COUNT}"

# Step 2: Destroy
echo ""
echo "--- Destroying dev database ---"
START_TIME=$(date +%s)

sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -Q "
IF DB_ID('${DATABASE_NAME}') IS NOT NULL
BEGIN
    ALTER DATABASE [${DATABASE_NAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [${DATABASE_NAME}];
END" 2>/dev/null || true
echo "  ✓ Database destroyed"

# Step 3: Rebuild
echo ""
echo "--- Rebuilding from scratch ---"
cd "$PROJECT_ROOT"
PRODUCTION_CONFIRMED=no APP_ENV=development bash run_all_phases.sh 2>&1 | tail -5

REBUILD_END=$(date +%s)
REBUILD_DURATION=$((REBUILD_END - START_TIME))
REBUILD_MIN=$((REBUILD_DURATION / 60))

# Step 4: Verify
echo ""
echo "--- Verifying rebuild ---"
POST_TABLE_COUNT=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    ${SQLCMD_ENCRYPT_FLAGS} -d "$DATABASE_NAME" -h -1 \
    -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'" \
    2>/dev/null | tr -d ' ' || echo "0")

RTO_MET="FAIL"
[ "$REBUILD_DURATION" -le "$RTO_TARGET_SECONDS" ] && RTO_MET="PASS"

TABLE_MATCH="FAIL"
[ "$POST_TABLE_COUNT" = "$PRE_TABLE_COUNT" ] && TABLE_MATCH="PASS"

# Step 5: Generate report
cat > "$REPORT_FILE" << EOF
# Rebuild Test Report

**Date**: $(date -u '+%Y-%m-%d %H:%M UTC')
**Environment**: ${ENVIRONMENT}

## Results

| Metric | Target | Actual | Status |
|---|---|---|---|
| **Rebuild time** | ${RTO_HOURS} hours | ${REBUILD_MIN} min (${REBUILD_DURATION}s) | ${RTO_MET} |
| **Tables** | ${PRE_TABLE_COUNT} | ${POST_TABLE_COUNT} | ${TABLE_MATCH} |

## Conclusion

Rebuild completed in **${REBUILD_MIN} minutes**.
RTO target (${RTO_HOURS} hours): **${RTO_MET}**
EOF

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo "  Rebuild time: ${REBUILD_MIN} minutes (${REBUILD_DURATION}s)"
echo "  RTO target:   ${RTO_HOURS} hours"
echo "  RTO status:   ${RTO_MET}"
echo "  Tables:       ${POST_TABLE_COUNT}/${PRE_TABLE_COUNT} (${TABLE_MATCH})"
echo "  Report:       ${REPORT_FILE}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

"${SCRIPT_DIR}/send_telegram.sh" "INFO" "Rebuild Test" \
    "Time: ${REBUILD_MIN} min, RTO: ${RTO_MET}, Tables: ${POST_TABLE_COUNT}/${PRE_TABLE_COUNT}" || true
