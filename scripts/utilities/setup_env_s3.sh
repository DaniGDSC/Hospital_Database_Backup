#!/usr/bin/env bash
set -euo pipefail

# Create environment-specific S3 buckets
# Each environment gets a separate isolated bucket
#
# ⚠️ REQUIRES AWS IAM: Must have s3:CreateBucket permission
# ⚠️ Bucket names must be globally unique — adjust suffix if needed

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

REGION="${S3_REGION:-ap-southeast-1}"

echo -e "${BLUE}=== S3 Bucket Setup for Environment: ${ENVIRONMENT} ===${NC}"
echo ""

case "${ENVIRONMENT}" in
    development)
        BUCKET="hospital-backup-dev"
        echo "Creating dev bucket (no Object Lock)..."
        aws s3 mb "s3://${BUCKET}" --region "$REGION" 2>/dev/null || echo "  Bucket may already exist"
        echo -e "  ${GREEN}✓${NC} s3://${BUCKET} (dev — no Object Lock)"
        ;;

    staging)
        BUCKET="hospital-backup-staging"
        echo "Creating staging bucket with versioning..."
        aws s3 mb "s3://${BUCKET}" --region "$REGION" 2>/dev/null || echo "  Bucket may already exist"
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET" \
            --versioning-configuration Status=Enabled \
            --region "$REGION" 2>/dev/null
        echo -e "  ${GREEN}✓${NC} s3://${BUCKET} (staging — versioning enabled)"
        ;;

    production)
        BUCKET="hospital-backup-prod-lock"
        echo "Production bucket should already exist with Object Lock."
        echo "Verifying..."
        if aws s3api get-object-lock-configuration --bucket "$BUCKET" --region "$REGION" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} s3://${BUCKET} (production — Object Lock active)"
        else
            echo -e "  ${YELLOW}WARN${NC}: Object Lock not confirmed on ${BUCKET}"
            echo "  Run: scripts/utilities/harden_cert_bucket.sh"
        fi
        ;;
esac

echo ""
echo "S3 bucket isolation:"
echo "  Dev:        s3://hospital-backup-dev"
echo "  Staging:    s3://hospital-backup-staging"
echo "  Production: s3://hospital-backup-prod-lock (Object Lock)"
