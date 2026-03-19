#!/usr/bin/env bash
set -euo pipefail

# Production Deployment Script with Separation of Duties
# HIPAA 164.308(a)(1): Enforces approval, logging, and verification
#
# Usage:
#   DEPLOY_APPROVER="senior_dba_mary" ./scripts/deploy_production.sh [--phase N]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
source "${SCRIPT_DIR}/helpers/load_config.sh"

DEPLOY_LOG="${PROJECT_ROOT}/logs/deployment_history.json"
DEPLOYER=$(whoami)
GIT_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "no-git")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PHASE_ARG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --phase) PHASE_ARG="$2"; shift 2 ;;
        *) echo "Usage: $0 [--phase N]"; exit 1 ;;
    esac
done

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Production Deployment — Separation of Duties           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Deployer:    ${DEPLOYER}"
echo "Environment: ${ENV:-production}"
echo "Git commit:  ${GIT_COMMIT}"
echo "Timestamp:   ${TIMESTAMP}"
echo ""

mkdir -p "${PROJECT_ROOT}/logs"

# ============================================
# GATE 1: Approval check
# ============================================
echo "--- Gate 1: Deployment Approval ---"

if [ -z "${DEPLOY_APPROVER:-}" ]; then
    echo "BLOCKED: DEPLOY_APPROVER environment variable is required"
    echo "  Usage: DEPLOY_APPROVER='approver_name' $0"
    exit 1
fi

if [ "$DEPLOY_APPROVER" = "$DEPLOYER" ]; then
    echo "BLOCKED: Self-approval is not permitted (HIPAA Separation of Duties)"
    echo "  Deployer '${DEPLOYER}' cannot also be the approver"
    exit 1
fi

echo "Approver: ${DEPLOY_APPROVER}"
echo ""
echo -e "\033[1;33m⚠  Type exactly: I approve deployment to production\033[0m"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "I approve deployment to production" ]; then
    echo "BLOCKED: Confirmation text did not match — deployment cancelled"
    exit 1
fi

echo "✓ Approval confirmed"
"${SCRIPT_DIR}/utilities/send_telegram.sh" "INFO" "Deployment Started" \
    "Deployer: ${DEPLOYER}, Approver: ${DEPLOY_APPROVER}, Commit: ${GIT_COMMIT}" || true
echo ""

# ============================================
# GATE 1.5: Version verification
# ============================================
echo "--- Gate 1.5: Tool Version Verification ---"

if ! "${SCRIPT_DIR}/utilities/verify_versions.sh"; then
    echo "BLOCKED: Version mismatch detected — fix before deploying"
    echo "{\"timestamp\":\"${TIMESTAMP}\",\"deployer\":\"${DEPLOYER}\",\"approver\":\"${DEPLOY_APPROVER}\",\"git_commit\":\"${GIT_COMMIT}\",\"environment\":\"${ENV:-production}\",\"status\":\"BLOCKED\",\"reason\":\"version mismatch\"}" >> "$DEPLOY_LOG"
    exit 1
fi

echo ""

# ============================================
# GATE 2: Pre-deployment checks
# ============================================
echo "--- Gate 2: Pre-deployment Validation ---"

if ! "${SCRIPT_DIR}/utilities/pre_deployment_check.sh"; then
    echo "BLOCKED: Pre-deployment checks failed — fix issues and retry"

    # Log blocked attempt
    echo "{\"timestamp\":\"${TIMESTAMP}\",\"deployer\":\"${DEPLOYER}\",\"approver\":\"${DEPLOY_APPROVER}\",\"git_commit\":\"${GIT_COMMIT}\",\"environment\":\"${ENV:-production}\",\"status\":\"BLOCKED\",\"reason\":\"pre-deployment checks failed\"}" >> "$DEPLOY_LOG"
    exit 1
fi

echo ""

# ============================================
# GATE 3: Execute deployment
# ============================================
echo "--- Gate 3: Executing Deployment ---"
echo ""

DEPLOY_STATUS="SUCCESS"
DEPLOY_ERROR=""

if [ -n "$PHASE_ARG" ]; then
    echo "Deploying phase ${PHASE_ARG} only..."
    if ! "${PROJECT_ROOT}/run_all_phases.sh" --phase "$PHASE_ARG" 2>&1; then
        DEPLOY_STATUS="FAILED"
        DEPLOY_ERROR="Phase ${PHASE_ARG} execution failed"
    fi
else
    echo "Deploying all phases..."
    if ! "${PROJECT_ROOT}/run_all_phases.sh" 2>&1; then
        DEPLOY_STATUS="FAILED"
        DEPLOY_ERROR="Pipeline execution failed"
    fi
fi

echo ""

# ============================================
# GATE 4: Post-deployment verification
# ============================================
if [ "$DEPLOY_STATUS" = "SUCCESS" ]; then
    echo "--- Gate 4: Post-deployment Verification ---"

    if sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
        -Q "SELECT name, state_desc FROM sys.databases WHERE name='HospitalBackupDemo'" \
        -h -1 2>/dev/null | grep -q "ONLINE"; then
        echo "✓ Database is ONLINE"
    else
        DEPLOY_STATUS="FAILED"
        DEPLOY_ERROR="Post-deployment: database not ONLINE"
        echo "✗ Database is NOT ONLINE — deployment may have failed"
    fi
fi

# ============================================
# Log deployment (append-only)
# ============================================
PHASE_DEPLOYED="all"
[ -n "$PHASE_ARG" ] && PHASE_DEPLOYED="$PHASE_ARG"

echo "{\"timestamp\":\"${TIMESTAMP}\",\"deployer\":\"${DEPLOYER}\",\"approver\":\"${DEPLOY_APPROVER}\",\"git_commit\":\"${GIT_COMMIT}\",\"environment\":\"${ENV:-production}\",\"phase\":\"${PHASE_DEPLOYED}\",\"status\":\"${DEPLOY_STATUS}\",\"error\":\"${DEPLOY_ERROR}\"}" >> "$DEPLOY_LOG"

echo ""
echo "═══════════════════════════════════════════════════"
if [ "$DEPLOY_STATUS" = "SUCCESS" ]; then
    "${SCRIPT_DIR}/utilities/send_telegram.sh" "INFO" "Deployment SUCCESS" \
        "Phase: ${PHASE_DEPLOYED}, Commit: ${GIT_COMMIT}, Deployer: ${DEPLOYER}" || true
    echo "✓ Production deployment completed successfully"
    echo "  Logged to: ${DEPLOY_LOG}"
    exit 0
else
    "${SCRIPT_DIR}/utilities/send_telegram.sh" "CRITICAL" "Deployment FAILED" \
        "Phase: ${PHASE_DEPLOYED}, Error: ${DEPLOY_ERROR}, Commit: ${GIT_COMMIT}" || true
    echo "✗ Deployment FAILED: ${DEPLOY_ERROR}"
    echo "  Logged to: ${DEPLOY_LOG}"
    echo "  Review logs and consider rollback: scripts/utilities/emergency_rollback.sh"
    exit 1
fi
