#!/usr/bin/env bash
set -euo pipefail

# Upload TDE certificate backup to S3 with client-side AES-256 encryption
# Requires: CERT_S3_ENCRYPTION_KEY environment variable (for openssl)
# Requires: AWS CLI configured with access to the backup bucket

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

CERT_DIR="/var/opt/mssql/backup/certificates"
S3_CERT_PATH="s3://${S3_BUCKET_NAME}/certificates"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/cert_s3_upload_${TIMESTAMP}.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

mkdir -p "${PROJECT_ROOT}/logs"

log "=== TDE Certificate S3 Upload ==="
log "Source: ${CERT_DIR}"
log "Destination: ${S3_CERT_PATH}"

# Validate encryption key is set
if [ -z "${CERT_S3_ENCRYPTION_KEY:-}" ]; then
    log "FATAL: CERT_S3_ENCRYPTION_KEY environment variable is required"
    log "  Set it via: export CERT_S3_ENCRYPTION_KEY='your-strong-passphrase'"
    exit 1
fi

# Validate source files exist
CER_FILE="${CERT_DIR}/HospitalBackupDemo_TDECert.cer"
PVK_FILE="${CERT_DIR}/HospitalBackupDemo_TDECert.pvk"

for f in "$CER_FILE" "$PVK_FILE"; do
    if [ ! -f "$f" ]; then
        log "FATAL: Certificate file not found: $f"
        log "  Run 02_create_certificates.sql first"
        exit 1
    fi
done

log "✓ Source files verified"

# Encrypt files client-side before upload
ENCRYPTED_DIR=$(mktemp -d)
trap 'rm -rf "$ENCRYPTED_DIR"' EXIT

log "Encrypting certificate files with AES-256-CBC..."

openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -in "$CER_FILE" \
    -out "${ENCRYPTED_DIR}/HospitalBackupDemo_TDECert.cer.enc" \
    -pass env:CERT_S3_ENCRYPTION_KEY

openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -in "$PVK_FILE" \
    -out "${ENCRYPTED_DIR}/HospitalBackupDemo_TDECert.pvk.enc" \
    -pass env:CERT_S3_ENCRYPTION_KEY

log "✓ Files encrypted to temporary directory"

# Upload to S3 with server-side KMS encryption and timestamped path
S3_DEST="${S3_CERT_PATH}/${TIMESTAMP}"
UPLOAD_FAILED=0

for enc_file in "${ENCRYPTED_DIR}"/*.enc; do
    BASENAME=$(basename "$enc_file")
    log "Uploading: ${BASENAME} -> ${S3_DEST}/${BASENAME}"

    if aws s3 cp "$enc_file" "${S3_DEST}/${BASENAME}" \
        --sse aws:kms \
        --region "${S3_REGION}" \
        2>>"$LOG_FILE"; then
        log "  ✓ Uploaded successfully"
    else
        log "  ✗ UPLOAD FAILED for ${BASENAME}"
        UPLOAD_FAILED=1
    fi
done

# Also upload a "latest" copy for easy retrieval
if [ $UPLOAD_FAILED -eq 0 ]; then
    log "Uploading 'latest' copies..."
    for enc_file in "${ENCRYPTED_DIR}"/*.enc; do
        BASENAME=$(basename "$enc_file")
        aws s3 cp "$enc_file" "${S3_CERT_PATH}/latest/${BASENAME}" \
            --sse aws:kms \
            --region "${S3_REGION}" \
            2>>"$LOG_FILE"
    done
    log "✓ Latest copies updated"
fi

# Verify upload by listing the destination
log ""
log "--- Verification: listing S3 destination ---"
aws s3 ls "${S3_DEST}/" --region "${S3_REGION}" 2>>"$LOG_FILE" | tee -a "$LOG_FILE"

ACTUAL_COUNT=$(aws s3 ls "${S3_DEST}/" --region "${S3_REGION}" 2>/dev/null | wc -l)
if [ "$ACTUAL_COUNT" -ge 2 ] && [ $UPLOAD_FAILED -eq 0 ]; then
    log ""
    log "✓ Certificate backup to S3 completed successfully (${ACTUAL_COUNT} files)"
    exit 0
else
    log ""
    log "✗ CRITICAL: Expected 2 files in S3 but found ${ACTUAL_COUNT}"
    exit 1
fi
