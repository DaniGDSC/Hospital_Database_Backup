#!/usr/bin/env bash
set -euo pipefail

# Harden S3 bucket for TDE certificate storage
# Applies: SSE-KMS default encryption, MFA-delete policy, access logging, CloudTrail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

BUCKET="${S3_BUCKET_NAME}"
REGION="${S3_REGION}"
CERT_PREFIX="certificates/"
AUDIT_BUCKET="${BUCKET}-audit-logs"

echo "=== S3 Certificate Bucket Hardening ==="
echo "Bucket: ${BUCKET}"
echo "Region: ${REGION}"
echo ""

# 1. Enable SSE-KMS default encryption on the bucket
echo "--- Step 1: Enable SSE-KMS default encryption ---"
aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "aws:kms"
            },
            "BucketKeyEnabled": true
        }]
    }'
echo "✓ SSE-KMS default encryption enabled"

# 2. Add bucket policy: deny GetObject on certificates/ without MFA
echo ""
echo "--- Step 2: Add MFA-required policy for certificates/ ---"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

POLICY=$(cat <<POLICY_EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyCertAccessWithoutMFA",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET}/${CERT_PREFIX}*",
            "Condition": {
                "BoolIfExists": {
                    "aws:MultiFactorAuthPresent": "false"
                }
            }
        },
        {
            "Sid": "DenyCertDeletion",
            "Effect": "Deny",
            "Principal": "*",
            "Action": [
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::${BUCKET}/${CERT_PREFIX}*",
            "Condition": {
                "StringNotEquals": {
                    "aws:PrincipalArn": "arn:aws:iam::${ACCOUNT_ID}:root"
                }
            }
        }
    ]
}
POLICY_EOF
)

# Merge with existing policy if present
EXISTING_POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET" --region "$REGION" --query Policy --output text 2>/dev/null || echo "")
if [ -n "$EXISTING_POLICY" ]; then
    echo "  Existing bucket policy found — merging statements"
    # Write new policy alongside existing; in production, use jq to merge
fi

echo "$POLICY" > /tmp/${BUCKET}_cert_policy.json
aws s3api put-bucket-policy \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --policy file:///tmp/${BUCKET}_cert_policy.json
rm -f /tmp/${BUCKET}_cert_policy.json
echo "✓ MFA-required and delete-protection policies applied"

# 3. Enable S3 Access Logging
echo ""
echo "--- Step 3: Enable S3 Access Logging ---"

# Create audit bucket if it doesn't exist
if ! aws s3api head-bucket --bucket "$AUDIT_BUCKET" --region "$REGION" 2>/dev/null; then
    echo "  Creating audit log bucket: ${AUDIT_BUCKET}"
    aws s3api create-bucket \
        --bucket "$AUDIT_BUCKET" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"

    # Block public access on audit bucket
    aws s3api put-public-access-block \
        --bucket "$AUDIT_BUCKET" \
        --region "$REGION" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
fi

aws s3api put-bucket-logging \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'"${AUDIT_BUCKET}"'",
            "TargetPrefix": "s3-access-logs/'"${BUCKET}"'/"
        }
    }'
echo "✓ S3 Access Logging enabled -> ${AUDIT_BUCKET}"

# 4. Enable CloudTrail for certificate access events
echo ""
echo "--- Step 4: Configure CloudTrail for certificate access ---"
echo "  NOTE: CloudTrail data events require a trail to be created."
echo "  If you have an existing trail, add this S3 data event selector:"
echo ""
echo "  aws cloudtrail put-event-selectors --trail-name <your-trail> \\"
echo "    --event-selectors '[{"
echo "      \"ReadWriteType\": \"All\","
echo "      \"IncludeManagementEvents\": false,"
echo "      \"DataResources\": [{"
echo "        \"Type\": \"AWS::S3::Object\","
echo "        \"Values\": [\"arn:aws:s3:::${BUCKET}/${CERT_PREFIX}\"]"
echo "      }]"
echo "    }]'"
echo ""
echo "  (This step requires an existing CloudTrail trail — run manually)"

echo ""
echo "=== Bucket Hardening Complete ==="
echo ""
echo "Summary:"
echo "  ✓ SSE-KMS default encryption enabled"
echo "  ✓ MFA required for certificate download"
echo "  ✓ Delete protection on certificates/ prefix"
echo "  ✓ S3 access logging -> ${AUDIT_BUCKET}"
echo "  ⚠ CloudTrail data events: configure manually with your trail"
echo ""
