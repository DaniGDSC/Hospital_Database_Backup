#!/usr/bin/env bash
set -euo pipefail

# Pre-deployment validation — blocks deploy if any check fails

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }

echo -e "${BLUE}=== Pre-Deployment Checks ===${NC}"
echo ""

# 1. Git status clean
echo -e "${BLUE}[1/7] Git working directory${NC}"
if [ -d "${PROJECT_ROOT}/.git" ]; then
    if [ -z "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
        pass "Working directory clean"
    else
        fail "Uncommitted changes — commit or stash before deploying"
    fi
else
    fail "Not a git repository"
fi

# 2. On main branch
echo ""
echo -e "${BLUE}[2/7] Git branch${NC}"
if [ -d "${PROJECT_ROOT}/.git" ]; then
    BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "unknown")
    if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
        pass "On branch: ${BRANCH}"
    else
        fail "On branch '${BRANCH}' — must deploy from main/master"
    fi
else
    fail "Cannot determine branch"
fi

# 3. SQL Server connection
echo ""
echo -e "${BLUE}[3/7] SQL Server connection${NC}"
if sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
    -Q "SELECT 1" -C &>/dev/null; then
    pass "SQL Server reachable at ${SERVER_CONN}"
else
    fail "Cannot connect to SQL Server at ${SERVER_CONN}"
fi

# 4. Disk space > 20%
echo ""
echo -e "${BLUE}[4/7] Disk space${NC}"
DISK_FREE_PCT=$(df /var/opt/mssql 2>/dev/null | tail -1 | awk '{print 100-$5}' | tr -d '%' || echo "0")
if [ "$DISK_FREE_PCT" -ge 20 ] 2>/dev/null; then
    pass "Disk free: ${DISK_FREE_PCT}%"
else
    fail "Disk free: ${DISK_FREE_PCT}% (need >= 20%)"
fi

# 5. Last backup within RPO window
echo ""
echo -e "${BLUE}[5/7] Backup recency (RPO check)${NC}"
LAST_BACKUP=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
    -h -1 -Q "SELECT DATEDIFF(MINUTE, MAX(backup_finish_date), GETDATE()) FROM msdb.dbo.backupset WHERE database_name='HospitalBackupDemo'" \
    2>/dev/null | tr -d ' ' || echo "9999")

if [ "$LAST_BACKUP" -le "${RPO_HOURS:-1}0" ] 2>/dev/null; then
    pass "Last backup: ${LAST_BACKUP} minutes ago (within RPO)"
else
    fail "Last backup: ${LAST_BACKUP} minutes ago (exceeds RPO of ${RPO_HOURS:-1} hour)"
fi

# 6. No long-running transactions
echo ""
echo -e "${BLUE}[6/7] Active transactions${NC}"
LONG_TX=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
    -h -1 -Q "SELECT COUNT(*) FROM sys.dm_exec_requests WHERE database_id=DB_ID('HospitalBackupDemo') AND total_elapsed_time > 300000" \
    2>/dev/null | tr -d ' ' || echo "0")

if [ "$LONG_TX" -eq 0 ] 2>/dev/null; then
    pass "No long-running transactions (> 5 min)"
else
    fail "${LONG_TX} transaction(s) running > 5 minutes"
fi

# 7. Maintenance window check (production only)
echo ""
echo -e "${BLUE}[7/7] Maintenance window${NC}"
if [ "${ENV:-development}" = "production" ]; then
    CURRENT_HOUR=$(date +%H)
    if [ "$CURRENT_HOUR" -ge 2 ] && [ "$CURRENT_HOUR" -lt 4 ]; then
        pass "Within maintenance window (02:00-04:00)"
    else
        fail "Outside maintenance window — current: ${CURRENT_HOUR}:00 (allowed: 02:00-04:00)"
    fi
else
    pass "Non-production environment — no window restriction"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All pre-deployment checks passed${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} check(s) failed — deployment blocked${NC}"
    exit 1
fi
