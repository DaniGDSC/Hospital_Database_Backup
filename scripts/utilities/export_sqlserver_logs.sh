#!/usr/bin/env bash
set -euo pipefail

# Export SQL Server security and error events to file for Promtail shipping
# Runs every 15 minutes via SQL Agent or cron

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

EXPORT_DIR="${PROJECT_ROOT}/logs/sqlserver"
TIMESTAMP=$(date +%Y%m%d_%H)
EXPORT_FILE="${EXPORT_DIR}/sqlserver_${TIMESTAMP}.log"

mkdir -p "$EXPORT_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$EXPORT_FILE"
}

# Export failed logins (security critical)
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -h -1 -s "," -W -Q "
SELECT
    CONVERT(VARCHAR(30), EventDate, 126) AS EventTime,
    'FAILED_LOGIN' AS EventType,
    LoginName,
    SourceIP,
    HostName,
    ErrorMessage
FROM HospitalBackupDemo.dbo.SecurityEvents
WHERE EventType = 'Login Failed'
  AND EventDate >= DATEADD(MINUTE, -15, GETDATE())
ORDER BY EventDate DESC
" 2>/dev/null >> "$EXPORT_FILE" || true

# Export backup events
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -h -1 -s "," -W -Q "
SELECT
    CONVERT(VARCHAR(30), backup_finish_date, 126) AS EventTime,
    'BACKUP_' + CASE type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' END AS EventType,
    database_name,
    CAST(backup_size/1048576 AS INT) AS SizeMB,
    DATEDIFF(SECOND, backup_start_date, backup_finish_date) AS DurationSec,
    CASE WHEN has_backup_checksums = 1 THEN 'CHECKSUM_OK' ELSE 'NO_CHECKSUM' END AS Integrity
FROM msdb.dbo.backupset
WHERE database_name = 'HospitalBackupDemo'
  AND backup_finish_date >= DATEADD(MINUTE, -15, GETDATE())
ORDER BY backup_finish_date DESC
" 2>/dev/null >> "$EXPORT_FILE" || true

# Export RBAC changes (from SecurityAuditEvents)
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -h -1 -s "," -W -Q "
SELECT
    CONVERT(VARCHAR(30), EventTime, 126) AS EventTime,
    EventType,
    LoginName,
    ObjectName,
    Action,
    CASE Success WHEN 1 THEN 'SUCCESS' ELSE 'BLOCKED' END AS Result
FROM HospitalBackupDemo.dbo.SecurityAuditEvents
WHERE EventTime >= DATEADD(MINUTE, -15, GETDATE())
ORDER BY EventTime DESC
" 2>/dev/null >> "$EXPORT_FILE" || true

# Export TDE status
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -h -1 -s "," -W -Q "
SELECT
    CONVERT(VARCHAR(30), GETDATE(), 126) AS CheckTime,
    'TDE_STATUS' AS EventType,
    d.name AS DatabaseName,
    CASE dek.encryption_state
        WHEN 3 THEN 'ENCRYPTED'
        WHEN 2 THEN 'ENCRYPTING'
        WHEN 1 THEN 'DECRYPTING'
        ELSE 'UNKNOWN'
    END AS Status
FROM sys.dm_database_encryption_keys dek
JOIN sys.databases d ON dek.database_id = d.database_id
WHERE d.name = 'HospitalBackupDemo'
" 2>/dev/null >> "$EXPORT_FILE" || true

LINES=$(wc -l < "$EXPORT_FILE" 2>/dev/null || echo "0")
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] SQL Server log export: ${LINES} lines -> ${EXPORT_FILE}"

# Clean exports older than 7 days
find "$EXPORT_DIR" -name "sqlserver_*.log" -type f -mtime +7 -delete 2>/dev/null

exit 0
