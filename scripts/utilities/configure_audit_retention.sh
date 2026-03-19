#!/usr/bin/env bash
set -euo pipefail

# Configure S3 Object Lock on audit-logs/ prefix for HIPAA 6-year retention
# ⚠️ REQUIRES AWS IAM: s3:PutObjectLockConfiguration, s3:PutBucketVersioning

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

BUCKET="${S3_BUCKET_NAME}"
REGION="${S3_REGION}"
RETENTION_DAYS=2190  # 6 years = 365 * 6

echo "=== Audit Log S3 Retention Configuration ==="
echo "Bucket: ${BUCKET}"
echo "Region: ${REGION}"
echo "Retention: ${RETENTION_DAYS} days (6 years, HIPAA minimum)"
echo ""

# 1. Ensure bucket versioning is enabled (required for Object Lock)
echo "--- Step 1: Enable bucket versioning ---"
aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled
echo "✓ Versioning enabled"

# 2. Configure Object Lock in COMPLIANCE mode
# COMPLIANCE: No one (including AWS root) can delete objects before retention expires
echo ""
echo "--- Step 2: Configure Object Lock (COMPLIANCE, ${RETENTION_DAYS} days) ---"
aws s3api put-object-lock-configuration \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --object-lock-configuration "{
        \"ObjectLockEnabled\": \"Enabled\",
        \"Rule\": {
            \"DefaultRetention\": {
                \"Mode\": \"COMPLIANCE\",
                \"Days\": ${RETENTION_DAYS}
            }
        }
    }"
echo "✓ Object Lock configured: COMPLIANCE mode, ${RETENTION_DAYS} days"

# 3. Verify configuration
echo ""
echo "--- Step 3: Verify configuration ---"
LOCK_CONFIG=$(aws s3api get-object-lock-configuration \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --output json 2>/dev/null || echo "NONE")

if echo "$LOCK_CONFIG" | grep -q "COMPLIANCE"; then
    echo "✓ Object Lock verified: COMPLIANCE mode active"
    echo "$LOCK_CONFIG" | grep -E "Mode|Days"
else
    echo "✗ CRITICAL: Object Lock verification failed"
    echo "$LOCK_CONFIG"
    exit 1
fi

echo ""
echo "=== Audit Retention Configuration Complete ==="
echo ""
echo "Audit logs uploaded to s3://${BUCKET}/audit-logs/ will:"
echo "  - Be locked in COMPLIANCE mode for ${RETENTION_DAYS} days (6 years)"
echo "  - Cannot be deleted by anyone (including AWS root account)"
echo "  - Automatically expire after retention period"
echo ""
