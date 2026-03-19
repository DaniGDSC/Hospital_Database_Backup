#!/usr/bin/env bash
set -euo pipefail

# Configure S3 Lifecycle for audit logs: Glacier after 1 year, delete after 6 years
# ⚠️ REQUIRES AWS IAM: s3:PutLifecycleConfiguration

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

BUCKET="${S3_BUCKET_NAME}"
REGION="${S3_REGION}"

echo "=== Audit Log Lifecycle Configuration ==="
echo "Bucket: ${BUCKET}"
echo ""

LIFECYCLE_CONFIG=$(cat <<'LIFECYCLE'
{
    "Rules": [
        {
            "ID": "AuditLogGlacierTransition",
            "Filter": {
                "Prefix": "audit-logs/"
            },
            "Status": "Enabled",
            "Transitions": [
                {
                    "Days": 365,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": 2220
            }
        }
    ]
}
LIFECYCLE
)

echo "$LIFECYCLE_CONFIG" > /tmp/audit_lifecycle.json

aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --lifecycle-configuration file:///tmp/audit_lifecycle.json

rm -f /tmp/audit_lifecycle.json

echo "✓ Lifecycle configured:"
echo "  - audit-logs/* -> Glacier after 365 days"
echo "  - audit-logs/* -> Expire after 2220 days (6 years + 30 days buffer)"
echo "  - Object Lock prevents deletion before retention expires"
echo ""

# Verify
echo "--- Verification ---"
aws s3api get-bucket-lifecycle-configuration \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --output table 2>/dev/null || echo "  (Use 'aws s3api get-bucket-lifecycle-configuration' to verify)"
echo ""
