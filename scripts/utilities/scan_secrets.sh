#!/usr/bin/env bash
set -euo pipefail

# Manual secrets scan — run anytime to check for leaked credentials
# Uses gitleaks to scan repo history and staged files

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/secrets_scan_${TIMESTAMP}.log"

mkdir -p "${PROJECT_ROOT}/logs"

echo "=== Secrets Scan ==="
echo "Project: ${PROJECT_ROOT}"
echo "Log:     ${LOG_FILE}"
echo ""

if ! command -v gitleaks &>/dev/null; then
    echo "ERROR: gitleaks not installed"
    echo "Install: go install github.com/gitleaks/gitleaks/v8@latest"
    echo "  or: brew install gitleaks"
    exit 1
fi

FAIL=0

# Scan 1: Current working directory (all files)
echo "--- Scan 1: Working directory ---"
if gitleaks detect --source "$PROJECT_ROOT" \
    --config "${PROJECT_ROOT}/.gitleaks.toml" \
    --report-path "$LOG_FILE" \
    --no-git 2>&1; then
    echo "  PASS: No secrets in working directory"
else
    echo "  FAIL: Secrets detected — see ${LOG_FILE}"
    FAIL=1
fi

# Scan 2: Git history (if git repo)
if [ -d "${PROJECT_ROOT}/.git" ]; then
    echo ""
    echo "--- Scan 2: Git history ---"
    HISTORY_LOG="${PROJECT_ROOT}/logs/secrets_history_${TIMESTAMP}.log"
    if gitleaks detect --source "$PROJECT_ROOT" \
        --config "${PROJECT_ROOT}/.gitleaks.toml" \
        --report-path "$HISTORY_LOG" 2>&1; then
        echo "  PASS: No secrets in git history"
    else
        echo "  FAIL: Secrets in git history — see ${HISTORY_LOG}"
        echo "  Fix: Use git filter-branch or BFG to remove"
        FAIL=1
    fi
fi

echo ""
if [ $FAIL -eq 0 ]; then
    echo "✓ All secrets scans PASSED"
    exit 0
else
    echo "✗ Secrets detected — review logs and remove before pushing"
    exit 1
fi
