#!/usr/bin/env bash
set -euo pipefail

# Hospital Database Server Setup — Infrastructure as Code
# HIPAA: Every step = Execute + Verify + Log + Stop on failure
#
# Usage: sudo bash scripts/setup_server.sh
# Requires: .env file with all secrets configured
# Output: logs/setup_YYYYMMDD_HHMMSS.log (audit trail)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SETUP_LOG="${PROJECT_ROOT}/logs/setup_${TIMESTAMP}.log"
SETUP_START=$(date +%s)
STEP_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

mkdir -p "${PROJECT_ROOT}/logs"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() {
    local msg="[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1"
    echo "$msg" >> "$SETUP_LOG"
    echo -e "$1"
}

# Core: run step with execute + verify + log
run_step() {
    local step_num="$1"
    local step_name="$2"
    local exec_cmd="$3"
    local verify_cmd="$4"

    STEP_COUNT=$((STEP_COUNT + 1))

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "Step ${step_num}: ${step_name}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Execute
    if eval "$exec_cmd" >> "$SETUP_LOG" 2>&1; then
        log "  Execute: OK"
    else
        log "${RED}  ✗ FAIL: ${step_name} — execution failed${NC}"
        echo "FAIL EXEC step=${step_num} name=${step_name}" >> "$SETUP_LOG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi

    # Verify
    if eval "$verify_cmd" >> "$SETUP_LOG" 2>&1; then
        log "${GREEN}  ✓ PASS: ${step_name}${NC}"
        echo "PASS step=${step_num} name=${step_name}" >> "$SETUP_LOG"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "${RED}  ✗ FAIL: ${step_name} — verification failed${NC}"
        echo "FAIL VERIFY step=${step_num} name=${step_name}" >> "$SETUP_LOG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Hospital Database Server Setup (IaC)                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "Setup started by: $(whoami)"
log "Log: ${SETUP_LOG}"

# ═══════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════

run_step 1 "Environment config loaded" \
    "source ${SCRIPT_DIR}/helpers/load_config.sh" \
    "[ -n '${DATABASE_NAME:-}' ]"

run_step 2 "Secrets validated" \
    "source ${SCRIPT_DIR}/helpers/load_config.sh && validate_secrets" \
    "[ -n '${SQL_PASSWORD:-}' ]"

run_step 3 "Tool versions verified" \
    "bash ${SCRIPT_DIR}/utilities/verify_versions.sh" \
    "true"

# ═══════════════════════════════════
# INFRASTRUCTURE
# ═══════════════════════════════════

run_step 4 "Docker available" \
    "docker --version" \
    "docker compose version"

run_step 5 "Monitoring stack started" \
    "cd ${PROJECT_ROOT} && docker compose up -d loki promtail prometheus node-exporter grafana" \
    "curl -sf http://localhost:3000/api/health | grep -q ok"

# ═══════════════════════════════════
# SQL SERVER CONNECTION
# ═══════════════════════════════════

run_step 6 "SQL Server reachable" \
    "source ${SCRIPT_DIR}/helpers/load_config.sh" \
    "sqlcmd -S ${SERVER_CONN:-127.0.0.1,14333} -U ${SQL_USER:-sa} -P '${SQL_PASSWORD}' ${SQLCMD_ENCRYPT_FLAGS:-'-C'} -Q 'SELECT 1' -b"

# ═══════════════════════════════════
# DATABASE DEPLOYMENT
# ═══════════════════════════════════

run_step 7 "Database phases deployed" \
    "cd ${PROJECT_ROOT} && bash run_all_phases.sh" \
    "sqlcmd -S ${SERVER_CONN:-127.0.0.1,14333} -U ${SQL_USER:-sa} -P '${SQL_PASSWORD}' ${SQLCMD_ENCRYPT_FLAGS:-'-C'} -Q 'SELECT COUNT(*) FROM HospitalBackupDemo.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='\''BASE TABLE'\''' -h -1 | grep -q '18'"

# ═══════════════════════════════════
# SECURITY VERIFICATION
# ═══════════════════════════════════

run_step 8 "TDE encryption active" \
    "echo 'Checking TDE...'" \
    "sqlcmd -S ${SERVER_CONN:-127.0.0.1,14333} -U ${SQL_USER:-sa} -P '${SQL_PASSWORD}' ${SQLCMD_ENCRYPT_FLAGS:-'-C'} -Q 'SELECT encryption_state FROM sys.dm_database_encryption_keys WHERE database_id=DB_ID('\''HospitalBackupDemo'\'')' -h -1 | grep -q '3'"

run_step 9 "Audit tables protected" \
    "echo 'Checking audit protection...'" \
    "sqlcmd -S ${SERVER_CONN:-127.0.0.1,14333} -U ${SQL_USER:-sa} -P '${SQL_PASSWORD}' ${SQLCMD_ENCRYPT_FLAGS:-'-C'} -d HospitalBackupDemo -Q 'SELECT COUNT(*) FROM sys.triggers WHERE name='\''trg_Protect_AuditTables'\''' -h -1 | grep -q '1'"

run_step 10 "SQL Agent jobs deployed" \
    "echo 'Checking jobs...'" \
    "sqlcmd -S ${SERVER_CONN:-127.0.0.1,14333} -U ${SQL_USER:-sa} -P '${SQL_PASSWORD}' ${SQLCMD_ENCRYPT_FLAGS:-'-C'} -d msdb -Q 'SELECT COUNT(*) FROM sysjobs WHERE name LIKE '\''HospitalBackup_%'\''' -h -1 | tr -d ' ' | grep -qE '[0-9]'"

# ═══════════════════════════════════
# MONITORING VERIFICATION
# ═══════════════════════════════════

run_step 11 "Grafana healthy" \
    "echo 'Checking Grafana...'" \
    "curl -sf http://localhost:3000/api/health | grep -q ok"

run_step 12 "Loki healthy" \
    "echo 'Checking Loki...'" \
    "curl -sf http://localhost:3100/ready | grep -qi ready"

# ═══════════════════════════════════
# FINAL REPORT
# ═══════════════════════════════════

SETUP_END=$(date +%s)
DURATION=$(( SETUP_END - SETUP_START ))
DURATION_MIN=$(( DURATION / 60 ))

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    SETUP REPORT                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "Duration:     ${DURATION_MIN} minutes (${DURATION} seconds)"
log "Steps:        ${STEP_COUNT}"
log "Passed:       ${PASS_COUNT}"
log "Failed:       ${FAIL_COUNT}"
log "Log:          ${SETUP_LOG}"
echo ""

echo "SUMMARY duration=${DURATION}s steps=${STEP_COUNT} pass=${PASS_COUNT} fail=${FAIL_COUNT}" >> "$SETUP_LOG"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}✗ SETUP FAILED — ${FAIL_COUNT} error(s)${NC}"
    echo "  Review: ${SETUP_LOG}"
    "${SCRIPT_DIR}/utilities/send_telegram.sh" "CRITICAL" "Server Setup FAILED" \
        "${FAIL_COUNT} errors in ${DURATION_MIN} min. Review: ${SETUP_LOG}" || true
    exit 1
fi

echo -e "${GREEN}✓ ALL ${STEP_COUNT} STEPS PASSED${NC}"
echo ""
echo -e "${YELLOW}⚠️  REQUIRED: Senior DBA must review and approve setup${NC}"
echo "   Log: ${SETUP_LOG}"
echo "   Approve: bash scripts/utilities/approve_setup.sh ${SETUP_LOG}"

"${SCRIPT_DIR}/utilities/send_telegram.sh" "INFO" "Server Setup Complete" \
    "${STEP_COUNT}/${STEP_COUNT} steps passed in ${DURATION_MIN} min. DBA review required." || true
