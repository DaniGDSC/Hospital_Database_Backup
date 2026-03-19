#!/usr/bin/env bash
set -euo pipefail

# Emergency disk space cleanup
# ⚠️ REQUIRES APPROVAL before running on production
# Only deletes files that are safe to remove

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

BACKUP_DIR="${BACKUP_ROOT:-/var/opt/mssql/backup}"

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         EMERGENCY DISK SPACE CLEANUP                        ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show current state
echo -e "${BLUE}=== Current Disk Usage ===${NC}"
df -h /var/opt/mssql 2>/dev/null || df -h /
echo ""

# Find candidates for cleanup
echo -e "${BLUE}=== Files Safe to Delete ===${NC}"
echo ""

TOTAL_RECOVERABLE=0

# 1. Temp files older than 1 day
echo -e "${CYAN}[1/4] Temp files (*.tmp, older than 1 day):${NC}"
TMP_SIZE=$(find "${BACKUP_DIR}" -name "*.tmp" -type f -mtime +1 -exec du -cm {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
echo "  Size: ${TMP_SIZE} MB"
TOTAL_RECOVERABLE=$((TOTAL_RECOVERABLE + TMP_SIZE))

# 2. Old differential backups (keep last 3)
echo ""
echo -e "${CYAN}[2/4] Old differential backups (keep last 3):${NC}"
DIFF_COUNT=$(find "${BACKUP_DIR}/differential" -name "*.bak" -type f 2>/dev/null | wc -l || echo "0")
if [ "$DIFF_COUNT" -gt 3 ]; then
    OLD_DIFF_SIZE=$(find "${BACKUP_DIR}/differential" -name "*.bak" -type f 2>/dev/null | sort | head -n $((DIFF_COUNT - 3)) | xargs du -cm 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    echo "  Old diffs to remove: $((DIFF_COUNT - 3)) files, ${OLD_DIFF_SIZE} MB"
    TOTAL_RECOVERABLE=$((TOTAL_RECOVERABLE + OLD_DIFF_SIZE))
else
    echo "  Only ${DIFF_COUNT} diff backups — nothing to remove"
fi

# 3. Old log backups beyond retention
echo ""
echo -e "${CYAN}[3/4] Log backups beyond ${LOG_BACKUP_RETENTION_HOURS:-168}h retention:${NC}"
RETENTION_DAYS=$(( ${LOG_BACKUP_RETENTION_HOURS:-168} / 24 ))
OLD_LOG_SIZE=$(find "${BACKUP_DIR}/log" -name "*.trn" -type f -mtime +${RETENTION_DAYS} -exec du -cm {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
echo "  Size: ${OLD_LOG_SIZE} MB"
TOTAL_RECOVERABLE=$((TOTAL_RECOVERABLE + OLD_LOG_SIZE))

# 4. Old pipeline log files
echo ""
echo -e "${CYAN}[4/4] Old script logs (>30 days):${NC}"
OLD_LOG_FILES=$(find "${PROJECT_ROOT}/logs" -name "*.log" -type f -mtime +30 -exec du -cm {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
echo "  Size: ${OLD_LOG_FILES} MB"
TOTAL_RECOVERABLE=$((TOTAL_RECOVERABLE + OLD_LOG_FILES))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  Total recoverable: ${GREEN}${TOTAL_RECOVERABLE} MB${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ "$TOTAL_RECOVERABLE" -eq 0 ]; then
    echo ""
    echo "No files safe to delete. Consider expanding disk."
    exit 0
fi

echo ""
echo -e "${YELLOW}⚠️  Type exactly: CONFIRM CLEANUP${NC}"
read -r CONFIRM
if [ "$CONFIRM" != "CONFIRM CLEANUP" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Executing cleanup..."

# Execute cleanup
find "${BACKUP_DIR}" -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null && echo "  ✓ Temp files cleaned"

if [ "$DIFF_COUNT" -gt 3 ]; then
    find "${BACKUP_DIR}/differential" -name "*.bak" -type f 2>/dev/null | sort | head -n $((DIFF_COUNT - 3)) | xargs rm -f 2>/dev/null
    echo "  ✓ Old differential backups cleaned"
fi

find "${BACKUP_DIR}/log" -name "*.trn" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null && echo "  ✓ Old log backups cleaned"
find "${PROJECT_ROOT}/logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null && echo "  ✓ Old script logs cleaned"

echo ""
echo -e "${BLUE}=== Post-Cleanup Disk Usage ===${NC}"
df -h /var/opt/mssql 2>/dev/null || df -h /

# Log the cleanup
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] EMERGENCY_CLEANUP by=$(whoami) recovered=${TOTAL_RECOVERABLE}MB" \
    >> "${PROJECT_ROOT}/logs/environment.log"

"${SCRIPT_DIR}/send_telegram.sh" "INFO" "Emergency Cleanup" \
    "Disk cleanup completed. Recovered: ${TOTAL_RECOVERABLE} MB" || true

echo ""
echo -e "${GREEN}✓ Cleanup complete. Recovered: ${TOTAL_RECOVERABLE} MB${NC}"
