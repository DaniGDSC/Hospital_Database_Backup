#!/usr/bin/env bash
set -euo pipefail

# Send incident alert per Communication Plan severity levels
# Usage: ./send_incident_alert.sh SEV-1 "Database DOWN — immediate action required"
#
# SEV-1: Telegram + Email + log
# SEV-2: Telegram + Email + log
# SEV-3: Email + log

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

SEVERITY="${1:-SEV-3}"
MESSAGE="${2:-Incident reported}"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
LOG_FILE="${PROJECT_ROOT}/logs/incidents.log"

mkdir -p "${PROJECT_ROOT}/logs"

log_incident() {
    echo "[${TIMESTAMP}] [${SEVERITY}] $1" >> "$LOG_FILE"
}

echo -e "${BLUE}=== Incident Alert: ${SEVERITY} ===${NC}"
echo "Message: ${MESSAGE}"
echo ""

log_incident "ALERT INITIATED: ${MESSAGE}"

# Map severity to Telegram severity
case "$SEVERITY" in
    SEV-1)
        TG_SEVERITY="CRITICAL"
        SUBJECT="SEV-1 CRITICAL: ${MESSAGE}"
        ;;
    SEV-2)
        TG_SEVERITY="WARNING"
        SUBJECT="SEV-2 HIGH: ${MESSAGE}"
        ;;
    SEV-3)
        TG_SEVERITY="INFO"
        SUBJECT="SEV-3 MEDIUM: ${MESSAGE}"
        ;;
    *)
        echo -e "${RED}Unknown severity: ${SEVERITY}${NC}"
        echo "Usage: $0 SEV-1|SEV-2|SEV-3 \"message\""
        exit 1
        ;;
esac

# Send Telegram (SEV-1 and SEV-2)
if [ "$SEVERITY" = "SEV-1" ] || [ "$SEVERITY" = "SEV-2" ]; then
    "${SCRIPT_DIR}/send_telegram.sh" "$TG_SEVERITY" "Incident: ${SEVERITY}" "$MESSAGE" || true
    log_incident "TELEGRAM: sent"
    echo -e "  ${GREEN}✓${NC} Telegram alert sent"
fi

# Send Email (all severities)
if command -v sqlcmd &>/dev/null && [ -n "${SQL_PASSWORD:-}" ]; then
    sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
        -Q "
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'HospitalBackupAlert',
            @recipients = '${NOTIFY_EMAIL}',
            @subject = '${SUBJECT}',
            @body = '${MESSAGE}

Timestamp: ${TIMESTAMP}
Environment: ${ENVIRONMENT}
Server: $(hostname)

-- Automated Incident Alert --';
        " 2>/dev/null && {
        log_incident "EMAIL: sent to ${NOTIFY_EMAIL}"
        echo -e "  ${GREEN}✓${NC} Email sent to ${NOTIFY_EMAIL}"
    } || {
        log_incident "EMAIL: failed (Database Mail may be unavailable)"
        echo -e "  ${YELLOW}⚠${NC} Email send failed (DB Mail may be down)"
    }
fi

# Log to AuditLog if SQL Server reachable
if [ "$SEVERITY" = "SEV-1" ] || [ "$SEVERITY" = "SEV-2" ]; then
    sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
        -d "HospitalBackupDemo" \
        -Q "INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
            VALUES (SYSDATETIME(), 'INCIDENT', 'dbo', 0, 'INSERT', 'INCIDENT_ALERT',
                    SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1,
                    CASE '${SEVERITY}' WHEN 'SEV-1' THEN 'Critical' ELSE 'High' END,
                    '${SEVERITY}: ${MESSAGE}');" \
        2>/dev/null || true
fi

log_incident "ALERT COMPLETE"
echo ""
echo -e "${GREEN}✓ Incident alert dispatched${NC}"
echo "  Log: ${LOG_FILE}"
