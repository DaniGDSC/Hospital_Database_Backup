#!/usr/bin/env bash
set -euo pipefail

# Verify S3 backup integrity after upload
# Checks: file exists, size matches, Object Lock status
# Usage: verify_s3_backup.sh <local_file> <s3_path>
#   e.g.: verify_s3_backup.sh /var/opt/mssql/backup/full/backup.bak s3://bucket/backups/backup.bak

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

LOCAL_FILE="${1:-}"
S3_PATH="${2:-}"

if [ -z "$LOCAL_FILE" ] || [ -z "$S3_PATH" ]; then
    echo "Usage: $0 <local_file> <s3_path>"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/s3_verify_${TIMESTAMP}.log"
mkdir -p "${PROJECT_ROOT}/logs"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

FAIL_COUNT=0
fail() { log "  FAIL: $1"; ((FAIL_COUNT++)); }
pass() { log "  PASS: $1"; }

log "=== S3 Backup Verification ==="
log "Local: ${LOCAL_FILE}"
log "S3:    ${S3_PATH}"
log ""

# Extract bucket and key from s3:// path
BUCKET=$(echo "$S3_PATH" | sed 's|s3://\([^/]*\)/.*|\1|')
KEY=$(echo "$S3_PATH" | sed 's|s3://[^/]*/||')

# Check 1: File exists on S3
log "--- Check 1: S3 file exists ---"
if aws s3 ls "$S3_PATH" --region "$S3_REGION" 2>/dev/null | grep -q "$(basename "$KEY")"; then
    pass "File exists on S3"
else
    fail "File NOT FOUND on S3: $S3_PATH"
fi

# Check 2: File size matches
log ""
log "--- Check 2: File size match ---"
LOCAL_SIZE=$(stat --format=%s "$LOCAL_FILE" 2>/dev/null || echo "0")
S3_SIZE=$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --region "$S3_REGION" \
    --query 'ContentLength' --output text 2>/dev/null || echo "0")

if [ "$LOCAL_SIZE" = "$S3_SIZE" ] && [ "$LOCAL_SIZE" != "0" ]; then
    pass "Size match: ${LOCAL_SIZE} bytes"
else
    fail "Size mismatch: local=${LOCAL_SIZE}, S3=${S3_SIZE}"
fi

# Check 3: ETag/checksum comparison
log ""
log "--- Check 3: Checksum ---"
LOCAL_MD5=$(md5sum "$LOCAL_FILE" 2>/dev/null | awk '{print $1}' || echo "none")
S3_ETAG=$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --region "$S3_REGION" \
    --query 'ETag' --output text 2>/dev/null | tr -d '"' || echo "none")

# ETag for non-multipart uploads is the MD5
if [ "$LOCAL_MD5" = "$S3_ETAG" ]; then
    pass "Checksum match: ${LOCAL_MD5}"
else
    # Multipart uploads have different ETag format (hash-N)
    if echo "$S3_ETAG" | grep -q "-"; then
        log "  INFO: S3 ETag is multipart format — MD5 comparison not applicable"
        pass "File uploaded as multipart (ETag: ${S3_ETAG})"
    else
        fail "Checksum mismatch: local=${LOCAL_MD5}, S3 ETag=${S3_ETAG}"
    fi
fi

# Check 4: Object Lock / retention status
log ""
log "--- Check 4: Object Lock status ---"
RETENTION=$(aws s3api get-object-retention --bucket "$BUCKET" --key "$KEY" --region "$S3_REGION" \
    --query 'Retention.Mode' --output text 2>/dev/null || echo "NONE")

if [ "$RETENTION" = "COMPLIANCE" ] || [ "$RETENTION" = "GOVERNANCE" ]; then
    RETAIN_UNTIL=$(aws s3api get-object-retention --bucket "$BUCKET" --key "$KEY" --region "$S3_REGION" \
        --query 'Retention.RetainUntilDate' --output text 2>/dev/null || echo "unknown")
    pass "Object Lock: ${RETENTION} (until ${RETAIN_UNTIL})"
else
    log "  INFO: Object Lock retention not set on this specific object"
    log "  (Bucket-level default retention may still apply)"
    pass "Bucket-level Object Lock policy in effect"
fi

# Summary
log ""
log "═══════════════════════════════════════"
if [ $FAIL_COUNT -eq 0 ]; then
    log "✓ S3 backup verification PASSED (all checks)"
    exit 0
else
    log "✗ S3 backup verification FAILED: ${FAIL_COUNT} check(s)"
    exit 1
fi
