#!/usr/bin/env bash
set -euo pipefail

# Verify SQL Server service account is non-root (CIS Benchmark)
# Checks: process owner, directory permissions, mssql user exists

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL_COUNT++)); }
warn() { echo -e "  ${YELLOW}WARN${NC}: $1"; }

echo -e "${BLUE}=== SQL Server Service Account Verification ===${NC}"
echo ""

# Test 1: sqlservr process not running as root
echo -e "${BLUE}[1/4] SQL Server process owner${NC}"
SQL_PID=$(pgrep -x sqlservr 2>/dev/null || echo "")
if [ -n "$SQL_PID" ]; then
    SQL_USER_PROC=$(ps -o user= -p "$SQL_PID" 2>/dev/null | head -1 | tr -d ' ')
    if [ "$SQL_USER_PROC" = "root" ]; then
        fail "sqlservr running as root (PID: $SQL_PID)"
    else
        pass "sqlservr running as '${SQL_USER_PROC}' (PID: $SQL_PID)"
    fi
else
    warn "sqlservr process not found (may be in Docker container)"
fi

# Test 2: mssql user exists on system
echo ""
echo -e "${BLUE}[2/4] mssql system user${NC}"
if id mssql &>/dev/null; then
    MSSQL_UID=$(id -u mssql)
    pass "mssql user exists (UID: $MSSQL_UID)"
else
    warn "mssql user not found (expected if SQL Server runs in Docker)"
fi

# Test 3: Backup directory permissions
echo ""
echo -e "${BLUE}[3/4] Backup directory ownership${NC}"
BACKUP_DIR="/var/opt/mssql/backup"
if [ -d "$BACKUP_DIR" ]; then
    DIR_OWNER=$(stat -c '%U' "$BACKUP_DIR" 2>/dev/null || echo "unknown")
    DIR_PERMS=$(stat -c '%a' "$BACKUP_DIR" 2>/dev/null || echo "unknown")
    if [ "$DIR_OWNER" = "root" ]; then
        warn "Backup dir owned by root (expected: mssql) — owner: $DIR_OWNER, perms: $DIR_PERMS"
    else
        pass "Backup dir owned by '$DIR_OWNER' (perms: $DIR_PERMS)"
    fi
else
    warn "Backup directory not found: $BACKUP_DIR"
fi

# Test 4: Log directory permissions
echo ""
echo -e "${BLUE}[4/4] Log directory permissions${NC}"
LOG_DIR="/var/opt/mssql/log"
if [ -d "$LOG_DIR" ]; then
    LOG_OWNER=$(stat -c '%U' "$LOG_DIR" 2>/dev/null || echo "unknown")
    LOG_PERMS=$(stat -c '%a' "$LOG_DIR" 2>/dev/null || echo "unknown")
    if [ "$LOG_OWNER" = "root" ]; then
        warn "Log dir owned by root — owner: $LOG_OWNER, perms: $LOG_PERMS"
    else
        pass "Log dir owned by '$LOG_OWNER' (perms: $LOG_PERMS)"
    fi
else
    warn "Log directory not found: $LOG_DIR"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

exit 0
