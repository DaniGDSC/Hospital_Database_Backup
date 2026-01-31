#!/usr/bin/env bash
set -euo pipefail

# Configure a new S3 bucket with Object Lock (WORM) and versioning enabled.
# This cannot be enabled on existing buckets; a new bucket is required.
# Usage: ./configure_s3_object_lock.sh <bucket-name> <region> [retention-days]

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <bucket-name> <region> [retention-days]"
  exit 1
fi

BUCKET="$1"
REGION="$2"
RETENTION_DAYS="${3:-30}"

echo "Creating Object Lock-enabled bucket: $BUCKET in $REGION (retention ${RETENTION_DAYS} days)"

# Create bucket with Object Lock enabled
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" \
  --object-lock-enabled-for-bucket

# Enable bucket versioning (required for Object Lock)
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# Configure default Object Lock retention in COMPLIANCE mode
aws s3api put-object-lock-configuration \
  --bucket "$BUCKET" \
  --object-lock-configuration \
  "ObjectLockEnabled=Enabled,Rule={DefaultRetention={Mode=COMPLIANCE,Days=$RETENTION_DAYS}}"

# Optional: bucket policy to deny deletes to non-root principals (defense-in-depth)
POLICY=$(cat <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyObjectDeletion",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::REPLACE_BUCKET/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": [
            "arn:aws:iam::REPLACE_ACCOUNT_ID:root"
          ]
        }
      }
    }
  ]
}
JSON
)

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_SAFE=${POLICY/REPLACE_BUCKET/$BUCKET}
POLICY_SAFE=${POLICY_SAFE/REPLACE_ACCOUNT_ID/$ACCOUNT_ID}

echo "$POLICY_SAFE" > /tmp/${BUCKET}_policy.json
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file:///tmp/${BUCKET}_policy.json

cat <<EOF

✓ S3 Object Lock bucket created: s3://$BUCKET
   - Versioning: Enabled
   - Object Lock: COMPLIANCE mode, default retention ${RETENTION_DAYS} days
   - Delete protection: Deny policy applied

Next steps:
  1) Update config/project.conf -> S3_BUCKET_NAME="$BUCKET"
  2) Ensure Phase 3 S3 backup scripts point to this bucket
  3) Existing bucket (without Object Lock) should be retained only as secondary storage if desired

EOF
