#!/usr/bin/env bash
set -euo pipefail

# Senior DBA setup approval — HIPAA audit requirement
# Creates signed approval record after human review
#
# Usage: bash scripts/utilities/approve_setup.sh logs/setup_YYYYMMDD.log

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

SETUP_LOG="${1:-}"
if [ -z "$SETUP_LOG" ] || [ ! -f "$SETUP_LOG" ]; then
    echo "Usage: $0 <setup_log_file>"
    echo "  Example: $0 logs/setup_20260319_020000.log"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Setup Approval — Senior DBA Review                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Show setup summary
echo "=== Setup Log Summary ==="
grep -E "^(PASS|FAIL|SUMMARY)" "$SETUP_LOG" || echo "(no summary found)"
echo ""

FAIL_LINES=$(grep -c "^FAIL" "$SETUP_LOG" 2>/dev/null || echo "0")
if [ "$FAIL_LINES" -gt 0 ]; then
    echo "⚠️  WARNING: ${FAIL_LINES} FAILED step(s) found in log"
    echo "Review failures before approving."
    echo ""
fi

# Compute log hash
LOG_HASH=$(sha256sum "$SETUP_LOG" | awk '{print $1}')
echo "Log file: ${SETUP_LOG}"
echo "SHA256:   ${LOG_HASH}"
echo ""

# Require approval
echo -e "\033[1;33m⚠️  Type exactly: I APPROVE THIS SETUP\033[0m"
read -r CONFIRMATION
if [ "$CONFIRMATION" != "I APPROVE THIS SETUP" ]; then
    echo "Approval cancelled."
    exit 1
fi

echo ""
read -r -p "Your name (for audit record): " APPROVER_NAME
read -r -p "Approval notes (optional): " APPROVAL_NOTES

# Create approval record
APPROVAL_FILE="${PROJECT_ROOT}/logs/setup_approval_$(date +%Y%m%d_%H%M%S).json"
cat > "$APPROVAL_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "approver": "${APPROVER_NAME}",
  "system_user": "$(whoami)",
  "setup_log": "${SETUP_LOG}",
  "setup_log_hash": "${LOG_HASH}",
  "failed_steps": ${FAIL_LINES},
  "notes": "${APPROVAL_NOTES}",
  "status": "APPROVED"
}
EOF

echo ""
echo "✓ Setup approved"
echo "  Approval record: ${APPROVAL_FILE}"
echo "  Approved by: ${APPROVER_NAME}"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Notify
"${SCRIPT_DIR}/send_telegram.sh" "INFO" "Setup Approved" \
    "Approved by: ${APPROVER_NAME}" || true
