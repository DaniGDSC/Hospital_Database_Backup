#!/usr/bin/env bash
set -euo pipefail

# Anonymize production data for staging environment
# HIPAA 45 CFR 164.514(b): De-identification of PHI
#
# Process: Backup prod → Restore as staging → Anonymize in-place → Verify
# ⚠️ NEVER copies PHI to staging without anonymization

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

STAGING_DB="HospitalBackupDemo_Staging"
PROD_DB="HospitalBackupDemo"
TEMP_BACKUP="/var/opt/mssql/backup/full/staging_seed_$(date +%Y%m%d).bak"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/anonymize_${TIMESTAMP}.log"

mkdir -p "${PROJECT_ROOT}/logs"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}=== Production → Staging Anonymization ===${NC}"
echo ""

# Safety check: must NOT be running as production
if [ "${ENVIRONMENT}" = "production" ] && [ "${ALLOW_DESTRUCTIVE_OPERATIONS:-false}" != "true" ]; then
    echo -e "${RED}ERROR: Cannot run anonymization while ENVIRONMENT=production${NC}"
    echo "  This script modifies data. Run with APP_ENV=staging"
    exit 1
fi

log "=== Anonymization started ==="
log "Source: ${PROD_DB}"
log "Target: ${STAGING_DB}"

# Step 1: Backup production
log ""
log "--- Step 1: Backup production database ---"
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -Q "BACKUP DATABASE [${PROD_DB}] TO DISK = '${TEMP_BACKUP}' WITH INIT, COMPRESSION, CHECKSUM" \
    2>&1 | tee -a "$LOG_FILE"
log "✓ Production backup created: ${TEMP_BACKUP}"

# Step 2: Restore as staging
log ""
log "--- Step 2: Restore as staging database ---"
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -Q "
IF DB_ID('${STAGING_DB}') IS NOT NULL
BEGIN
    ALTER DATABASE [${STAGING_DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [${STAGING_DB}];
END
RESTORE DATABASE [${STAGING_DB}] FROM DISK = '${TEMP_BACKUP}'
WITH MOVE 'HospitalBackupDemo_Data' TO '/var/opt/mssql/data/${STAGING_DB}.mdf',
     MOVE 'HospitalBackupDemo_Log'  TO '/var/opt/mssql/data/${STAGING_DB}_log.ldf',
     REPLACE;
" 2>&1 | tee -a "$LOG_FILE"
log "✓ Staging database restored"

# Step 3: Anonymize PHI
log ""
log "--- Step 3: Anonymize PHI ---"
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "${STAGING_DB}" -Q "
-- Patients: anonymize all identifying fields
UPDATE dbo.Patients SET
    FirstName    = 'Staging' + CAST(PatientID AS NVARCHAR(10)),
    LastName     = 'Patient',
    NationalID   = 'STG' + RIGHT('000000' + CAST(PatientID AS VARCHAR), 6),
    Phone        = '0000000000',
    Address      = 'Staging Test Address ' + CAST(PatientID AS NVARCHAR(10)),
    Email        = 'staging' + CAST(PatientID AS NVARCHAR(10)) + '@test.local',
    DateOfBirth  = DATEFROMPARTS(YEAR(DateOfBirth), 1, 1);

-- Doctors: anonymize contact info
UPDATE dbo.Doctors SET
    Phone = '0000000000',
    Email = 'dr' + CAST(DoctorID AS NVARCHAR(10)) + '@staging.local';

-- Nurses: anonymize contact info
UPDATE dbo.Nurses SET
    Phone = '0000000000',
    Email = 'nurse' + CAST(NurseID AS NVARCHAR(10)) + '@staging.local';

-- Staff: anonymize contact info
UPDATE dbo.Staff SET
    Phone = '0000000000',
    Email = 'staff' + CAST(StaffID AS NVARCHAR(10)) + '@staging.local';

-- MedicalRecords: remove free-text patient info from notes
UPDATE dbo.MedicalRecords SET
    Notes = 'Staging test notes for record ' + CAST(RecordID AS NVARCHAR(10));

-- Prescriptions: clear notes
UPDATE dbo.Prescriptions SET
    Notes = 'Staging prescription ' + CAST(PrescriptionID AS NVARCHAR(10));

PRINT '✓ All PHI anonymized in staging';
" 2>&1 | tee -a "$LOG_FILE"
log "✓ PHI anonymized"

# Step 4: Delete temp backup
log ""
log "--- Step 4: Cleanup ---"
rm -f "$TEMP_BACKUP"
log "✓ Temp backup deleted: ${TEMP_BACKUP}"

# Step 5: Verify
log ""
log "--- Step 5: Verification ---"
"${SCRIPT_DIR}/verify_anonymization.sh" 2>&1 | tee -a "$LOG_FILE"

log ""
log "=== Anonymization complete ==="
echo ""
echo -e "${GREEN}✓ Staging database ready: ${STAGING_DB}${NC}"
echo "  Verify: ./scripts/utilities/verify_anonymization.sh"
