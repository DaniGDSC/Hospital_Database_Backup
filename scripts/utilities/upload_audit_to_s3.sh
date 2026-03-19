#!/usr/bin/env bash
set -euo pipefail

# Upload encrypted audit log exports to S3 Object Lock (immutable)
# HIPAA 45 CFR 164.530(j): 6-year retention, tamper-proof
# Requires: AUDIT_EXPORT_PASSWORD environment variable

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

EXPORT_DIR="/var/opt/mssql/backup/audit-export"
S3_AUDIT_PATH="s3://${S3_BUCKET_NAME}/audit-logs"
DATE_STR=$(date -d "yesterday" +%Y%m%d)
YEAR=$(date -d "yesterday" +%Y)
MONTH=$(date -d "yesterday" +%m)
DAY=$(date -d "yesterday" +%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/audit_s3_upload_${TIMESTAMP}.log"

mkdir -p "${PROJECT_ROOT}/logs"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

log "=== Audit Log S3 Upload ==="
log "Source: ${EXPORT_DIR}"
log "Destination: ${S3_AUDIT_PATH}/${YEAR}/${MONTH}/${DAY}/"

# Validate encryption password
if [ -z "${AUDIT_EXPORT_PASSWORD:-}" ]; then
    log "FATAL: AUDIT_EXPORT_PASSWORD environment variable is required"
    exit 1
fi

# Find CSV files for yesterday
CSV_FILES=( "${EXPORT_DIR}"/audit_*_${DATE_STR}.csv )
if [ ! -f "${CSV_FILES[0]:-}" ]; then
    log "WARNING: No audit CSV files found for ${DATE_STR}"
    log "  Expected pattern: ${EXPORT_DIR}/audit_*_${DATE_STR}.csv"
    log "  Run usp_ExportAuditLogs first"
    exit 1
fi

log "Found ${#CSV_FILES[@]} CSV file(s) to upload"

ENCRYPTED_DIR=$(mktemp -d)
trap 'rm -rf "$ENCRYPTED_DIR"' EXIT

UPLOAD_FAILED=0
UPLOADED_COUNT=0

for csv_file in "${CSV_FILES[@]}"; do
    BASENAME=$(basename "$csv_file")
    ENC_FILE="${ENCRYPTED_DIR}/${BASENAME}.enc"
    S3_DEST="${S3_AUDIT_PATH}/${YEAR}/${MONTH}/${DAY}/${BASENAME}.enc"

    # Encrypt CSV with AES-256 before upload — plaintext never leaves server
    log "Encrypting: ${BASENAME}"
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
        -in "$csv_file" \
        -out "$ENC_FILE" \
        -pass env:AUDIT_EXPORT_PASSWORD

    # Upload encrypted file to S3 with server-side KMS encryption
    log "Uploading: ${BASENAME}.enc -> ${S3_DEST}"
    if aws s3 cp "$ENC_FILE" "$S3_DEST" \
        --sse aws:kms \
        --region "${S3_REGION}" \
        2>>"$LOG_FILE"; then
        log "  ✓ Uploaded"
        UPLOADED_COUNT=$((UPLOADED_COUNT + 1))
    else
        log "  ✗ UPLOAD FAILED: ${BASENAME}.enc"
        UPLOAD_FAILED=1
    fi
done

# Verify uploads
log ""
log "--- Verification ---"
ACTUAL_COUNT=$(aws s3 ls "${S3_AUDIT_PATH}/${YEAR}/${MONTH}/${DAY}/" \
    --region "${S3_REGION}" 2>/dev/null | wc -l || echo "0")
log "S3 files for ${YEAR}/${MONTH}/${DAY}: ${ACTUAL_COUNT}"

if [ "$ACTUAL_COUNT" -ge "$UPLOADED_COUNT" ] && [ $UPLOAD_FAILED -eq 0 ]; then
    log "✓ All ${UPLOADED_COUNT} file(s) uploaded and verified"
else
    log "✗ Verification failed: expected ${UPLOADED_COUNT}, found ${ACTUAL_COUNT}"
    "${SCRIPT_DIR}/send_telegram.sh" "CRITICAL" "Audit Log Export Failed" \
        "Audit logs not shipped to S3. HIPAA compliance at risk. Expected: ${UPLOADED_COUNT}, found: ${ACTUAL_COUNT}" || true
    exit 1
fi

# Delete local plaintext CSV after successful upload
log ""
log "--- Cleanup ---"
for csv_file in "${CSV_FILES[@]}"; do
    rm -f "$csv_file"
    log "  Deleted plaintext: $(basename "$csv_file")"
done

# Clean up encrypted local copies older than 7 days
find "${EXPORT_DIR}" -name "*.csv.enc" -type f -mtime +7 -delete 2>/dev/null
log "  Cleaned encrypted copies older than 7 days"

log ""
log "✓ Audit log S3 upload completed: ${UPLOADED_COUNT} file(s)"
exit 0
