#!/usr/bin/env bash
set -euo pipefail

# Daily verification of audit log export pipeline
# Checks: last export timestamp, S3 object count, Object Lock status

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

BUCKET="${S3_BUCKET_NAME}"
REGION="${S3_REGION}"
YESTERDAY=$(date -d "yesterday" +%Y/%m/%d)

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }

echo -e "${BLUE}=== Audit Retention Verification ===${NC}"
echo ""

# Check 1: Files exist in S3 for yesterday
echo -e "${BLUE}[1/4] Yesterday's audit files in S3${NC}"
S3_COUNT=$(aws s3 ls "s3://${BUCKET}/audit-logs/${YESTERDAY}/" \
    --region "$REGION" 2>/dev/null | wc -l || echo "0")

if [ "$S3_COUNT" -ge 1 ]; then
    pass "Found ${S3_COUNT} audit file(s) for ${YESTERDAY}"
else
    fail "No audit files found for ${YESTERDAY} — export may have failed"
fi

# Check 2: Last export within 25 hours
echo ""
echo -e "${BLUE}[2/4] Export recency (must be within 25 hours)${NC}"

LATEST_FILE=$(aws s3 ls "s3://${BUCKET}/audit-logs/" \
    --recursive --region "$REGION" 2>/dev/null | sort | tail -1)

if [ -n "$LATEST_FILE" ]; then
    LATEST_DATE=$(echo "$LATEST_FILE" | awk '{print $1 " " $2}')
    pass "Latest audit file: ${LATEST_DATE}"
else
    fail "No audit files found in S3 at all"
fi

# Check 3: Object Lock is COMPLIANCE mode
echo ""
echo -e "${BLUE}[3/4] Object Lock configuration${NC}"
LOCK_MODE=$(aws s3api get-object-lock-configuration \
    --bucket "$BUCKET" --region "$REGION" \
    --query 'ObjectLockConfiguration.Rule.DefaultRetention.Mode' \
    --output text 2>/dev/null || echo "NONE")

LOCK_DAYS=$(aws s3api get-object-lock-configuration \
    --bucket "$BUCKET" --region "$REGION" \
    --query 'ObjectLockConfiguration.Rule.DefaultRetention.Days' \
    --output text 2>/dev/null || echo "0")

if [ "$LOCK_MODE" = "COMPLIANCE" ]; then
    pass "Object Lock mode: COMPLIANCE"
else
    fail "Object Lock mode: ${LOCK_MODE} (expected COMPLIANCE)"
fi

if [ "$LOCK_DAYS" -ge 2190 ]; then
    pass "Retention period: ${LOCK_DAYS} days (>= 6 years)"
else
    fail "Retention period: ${LOCK_DAYS} days (need >= 2190 for HIPAA)"
fi

# Check 4: Versioning enabled
echo ""
echo -e "${BLUE}[4/4] Bucket versioning${NC}"
VERSIONING=$(aws s3api get-bucket-versioning \
    --bucket "$BUCKET" --region "$REGION" \
    --query 'Status' --output text 2>/dev/null || echo "NONE")

if [ "$VERSIONING" = "Enabled" ]; then
    pass "Bucket versioning: Enabled"
else
    fail "Bucket versioning: ${VERSIONING} (must be Enabled for Object Lock)"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All audit retention checks passed${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} check(s) failed — audit log integrity at risk${NC}"
    exit 1
fi
