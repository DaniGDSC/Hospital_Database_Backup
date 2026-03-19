#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=== Telegram Alert Test ==="
echo ""

"${SCRIPT_DIR}/send_telegram.sh" "INFO" "Alert Test" "This is a test message from HospitalBackupDemo. If you see this, Telegram alerting is working."

# Check log for result
sleep 3
LAST_LOG=$(tail -1 "${SCRIPT_DIR}/../../logs/telegram.log" 2>/dev/null || echo "no log")

if echo "$LAST_LOG" | grep -q "SENT"; then
    echo "✓ PASS: Telegram message sent successfully"
    echo "  Log: ${LAST_LOG}"
    exit 0
else
    echo "✗ FAIL: Telegram message not confirmed"
    echo "  Log: ${LAST_LOG}"
    echo "  Check: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in .env"
    exit 1
fi
