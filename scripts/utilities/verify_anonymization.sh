#!/usr/bin/env bash
set -euo pipefail

# Verify no PHI remains in staging database
# HIPAA 45 CFR 164.514(b): De-identification verification
# Must PASS before staging data is used for testing

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

STAGING_DB="HospitalBackupDemo_Staging"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }

echo -e "${BLUE}=== Staging Anonymization Verification ===${NC}"
echo "Database: ${STAGING_DB}"
echo ""

# Test 1: No real NationalID patterns (should all be STG prefix)
echo -e "${BLUE}[1/5] NationalID format check${NC}"
REAL_NIDS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "$STAGING_DB" -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.Patients WHERE NationalID NOT LIKE 'STG%' AND NationalID NOT LIKE 'DEV%' AND NationalID IS NOT NULL" \
    2>/dev/null | tr -d ' ' || echo "ERROR")

if [ "$REAL_NIDS" = "0" ]; then
    pass "All NationalIDs anonymized (STG/DEV prefix)"
elif [ "$REAL_NIDS" = "ERROR" ]; then
    fail "Cannot query staging database"
else
    fail "${REAL_NIDS} patients with non-anonymized NationalID"
fi

# Test 2: No real phone numbers
echo ""
echo -e "${BLUE}[2/5] Phone number check${NC}"
REAL_PHONES=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "$STAGING_DB" -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.Patients WHERE Phone != '0000000000' AND Phone IS NOT NULL" \
    2>/dev/null | tr -d ' ' || echo "ERROR")

if [ "${REAL_PHONES:-ERROR}" = "0" ]; then
    pass "All phone numbers anonymized"
else
    fail "${REAL_PHONES} patients with non-anonymized phone"
fi

# Test 3: Patient names are anonymized (should be StagingN Patient)
echo ""
echo -e "${BLUE}[3/5] Patient name check${NC}"
REAL_NAMES=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "$STAGING_DB" -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.Patients WHERE FirstName NOT LIKE 'Staging%' AND FirstName NOT LIKE 'Test%'" \
    2>/dev/null | tr -d ' ' || echo "ERROR")

if [ "${REAL_NAMES:-ERROR}" = "0" ]; then
    pass "All patient names anonymized"
else
    fail "${REAL_NAMES} patients with non-anonymized names"
fi

# Test 4: Email addresses anonymized
echo ""
echo -e "${BLUE}[4/5] Email check${NC}"
REAL_EMAILS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "$STAGING_DB" -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.Patients WHERE Email NOT LIKE '%staging%' AND Email NOT LIKE '%test%' AND Email IS NOT NULL" \
    2>/dev/null | tr -d ' ' || echo "ERROR")

if [ "${REAL_EMAILS:-ERROR}" = "0" ]; then
    pass "All email addresses anonymized"
else
    fail "${REAL_EMAILS} patients with non-anonymized email"
fi

# Test 5: DOB year-only (all should be Jan 1)
echo ""
echo -e "${BLUE}[5/5] Date of birth de-identification${NC}"
REAL_DOBS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "$STAGING_DB" -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.Patients WHERE MONTH(DateOfBirth) != 1 OR DAY(DateOfBirth) != 1" \
    2>/dev/null | tr -d ' ' || echo "ERROR")

if [ "${REAL_DOBS:-ERROR}" = "0" ]; then
    pass "All DOBs de-identified (year only)"
else
    fail "${REAL_DOBS} patients with full DOB (should be YYYY-01-01)"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}✗ ANONYMIZATION INCOMPLETE — DO NOT USE STAGING DATA${NC}"
    echo "  Re-run: ./scripts/utilities/anonymize_for_staging.sh"
    exit 1
else
    echo ""
    echo -e "${GREEN}✓ Staging data fully anonymized — safe for testing${NC}"
    exit 0
fi
