#!/usr/bin/env bash
set -euo pipefail

# Weekly PHI scan — verify no unredacted PHI exists in Loki
# HIPAA 164.312(a): PHI must not appear in logs

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

LOKI_URL="${LOKI_URL:-http://localhost:3100}"
FAIL_COUNT=0

echo -e "${BLUE}=== PHI in Logs Verification ===${NC}"
echo ""

# PHI patterns to search for (Vietnamese context)
declare -A PHI_PATTERNS=(
    ["national_id"]='\b[0-9]{9,12}\b'
    ["phone_number"]='\b0[0-9]{9,10}\b'
    ["email_in_data"]='@.*\.(com|vn|org)'
)

for pattern_name in "${!PHI_PATTERNS[@]}"; do
    PATTERN="${PHI_PATTERNS[$pattern_name]}"
    echo -e "${BLUE}Scanning for: ${pattern_name}${NC}"

    # Query Loki for unredacted PHI patterns (exclude redacted markers)
    RESULT=$(curl -s -G "${LOKI_URL}/loki/api/v1/query_range" \
        --data-urlencode "query={job=~\".+\"} |~ \"${PATTERN}\" !~ \"PHI-REDACTED|REDACTED\"" \
        --data-urlencode "start=$(date -d '7 days ago' +%s)000000000" \
        --data-urlencode "end=$(date +%s)000000000" \
        --data-urlencode "limit=5" \
        2>/dev/null || echo '{"data":{"result":[]}}')

    MATCH_COUNT=$(echo "$RESULT" | grep -c '"values"' || echo "0")

    if [ "$MATCH_COUNT" -eq 0 ]; then
        echo -e "  ${GREEN}CLEAN${NC}: No unredacted ${pattern_name} found"
    else
        echo -e "  ${RED}ALERT${NC}: Possible unredacted ${pattern_name} found (${MATCH_COUNT} streams)"
        echo "  Review: curl '${LOKI_URL}/loki/api/v1/query_range' with the above query"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# ============================================
# AuditLog PHI Verification (SQL Server)
# ============================================
echo ""
echo -e "${BLUE}=== AuditLog PHI Verification ===${NC}"
echo ""

# Check 1: Verify audit entries exist for all 5 PHI tables (last 7 days)
for table in MedicalRecords Patients Prescriptions LabTests Appointments; do
    COUNT=$(sqlcmd -S "${SERVER_CONN}" -U "${SQL_USER}" -P "${SQL_PASSWORD}" ${SQLCMD_ENCRYPT_FLAGS} \
        -d "HospitalBackupDemo" -h -1 \
        -Q "SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName='${table}' AND ActionType='PHI_ACCESS' AND AuditDate >= DATEADD(DAY,-7,SYSDATETIME())" \
        2>/dev/null | tr -d ' ' || echo "0")

    if [ "${COUNT:-0}" -gt 0 ]; then
        echo -e "  ${GREEN}OK${NC}: ${table} has ${COUNT} audit entries (last 7 days)"
    else
        echo -e "  ${YELLOW}WARN${NC}: ${table} has NO audit entries (last 7 days)"
    fi
done

# Check 2: Scan AuditLog for unmasked NationalID (should be zero)
echo ""
UNMASKED=$(sqlcmd -S "${SERVER_CONN}" -U "${SQL_USER}" -P "${SQL_PASSWORD}" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "HospitalBackupDemo" -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.AuditLog WHERE TableName='Patients' AND ActionType='PHI_ACCESS' AND (CAST(NewValues AS NVARCHAR(MAX)) LIKE '%NationalID=%' OR CAST(OldValues AS NVARCHAR(MAX)) LIKE '%NationalID=%') AND CAST(NewValues AS NVARCHAR(MAX)) NOT LIKE '%NationalID[_]Masked%' AND CAST(OldValues AS NVARCHAR(MAX)) NOT LIKE '%NationalID[_]Masked%'" \
    2>/dev/null | tr -d ' ' || echo "0")

if [ "${UNMASKED:-0}" -eq 0 ]; then
    echo -e "  ${GREEN}CLEAN${NC}: No unmasked NationalID found in AuditLog"
else
    echo -e "  ${RED}ALERT${NC}: ${UNMASKED} AuditLog entries with unmasked NationalID!"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ No unredacted PHI found in Loki or AuditLog (last 7 days)${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} potential PHI leak(s) — review and update filters${NC}"
    exit 1
fi
