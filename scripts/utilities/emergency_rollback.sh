#!/usr/bin/env bash
set -euo pipefail

# Emergency rollback procedure
# Usage:
#   ./scripts/utilities/emergency_rollback.sh --to-phase 1
#   ./scripts/utilities/emergency_rollback.sh --to-commit abc123

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

ROLLBACK_DIR="${PROJECT_ROOT}/phases/phase1-database/schema/rollback"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/rollback_${TIMESTAMP}.log"

mkdir -p "${PROJECT_ROOT}/logs"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

TARGET_PHASE=""
TARGET_COMMIT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --to-phase) TARGET_PHASE="$2"; shift 2 ;;
        --to-commit) TARGET_COMMIT="$2"; shift 2 ;;
        *) echo "Usage: $0 --to-phase [1-7] | --to-commit [hash]"; exit 1 ;;
    esac
done

if [ -z "$TARGET_PHASE" ] && [ -z "$TARGET_COMMIT" ]; then
    echo "Usage: $0 --to-phase [1-7] | --to-commit [hash]"
    exit 1
fi

log "╔════════════════════════════════════════════════════════════════╗"
log "║         EMERGENCY ROLLBACK                                      ║"
log "╚════════════════════════════════════════════════════════════════╝"
log ""
log "Operator:  $(whoami)"
log "Target:    ${TARGET_PHASE:+phase $TARGET_PHASE}${TARGET_COMMIT:+commit $TARGET_COMMIT}"
log ""

# Safety confirmation
echo -e "${RED}WARNING: This will modify the production database.${NC}"
echo -e "${YELLOW}Type exactly: CONFIRM ROLLBACK${NC}"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "CONFIRM ROLLBACK" ]; then
    log "CANCELLED: Confirmation text did not match"
    exit 1
fi

# Step 1: Emergency backup before rollback
log "--- Step 1: Emergency backup ---"
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -Q "BACKUP DATABASE HospitalBackupDemo TO DISK = '/var/opt/mssql/backup/full/HospitalBackupDemo_PRE_ROLLBACK_${TIMESTAMP}.bak' WITH INIT, COMPRESSION, CHECKSUM" \
    2>&1 | tee -a "$LOG_FILE"
log "✓ Emergency backup completed"

# Step 2: Execute rollback scripts in reverse order
log ""
log "--- Step 2: Execute rollback ---"

# Rollback order: system tables → billing → clinical → core
ROLLBACK_SCRIPTS=(
    "${ROLLBACK_DIR}/rollback_system_tables.sql"
    "${ROLLBACK_DIR}/rollback_billing_tables.sql"
    "${ROLLBACK_DIR}/rollback_clinical_tables.sql"
    "${ROLLBACK_DIR}/rollback_core_tables.sql"
)

for script in "${ROLLBACK_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        log "Executing: $(basename "$script")"
        sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
            -d HospitalBackupDemo \
            -i "$script" 2>&1 | tee -a "$LOG_FILE"
        log "  ✓ Completed"
    else
        log "  SKIP: $(basename "$script") not found"
    fi
done

# Step 3: Verify
log ""
log "--- Step 3: Verification ---"
TABLE_COUNT=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -h -1 -Q "SELECT COUNT(*) FROM HospitalBackupDemo.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'" \
    2>/dev/null | tr -d ' ')
log "Remaining tables: ${TABLE_COUNT}"

# Log to deployment history
DEPLOY_LOG="${PROJECT_ROOT}/logs/deployment_history.json"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"deployer\":\"$(whoami)\",\"approver\":\"EMERGENCY\",\"git_commit\":\"$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'n/a')\",\"environment\":\"${ENV:-production}\",\"status\":\"ROLLBACK\",\"target\":\"${TARGET_PHASE:-$TARGET_COMMIT}\"}" >> "$DEPLOY_LOG"

log ""
log "✓ Rollback completed — review logs at ${LOG_FILE}"
log "  Emergency backup: /var/opt/mssql/backup/full/HospitalBackupDemo_PRE_ROLLBACK_${TIMESTAMP}.bak"
