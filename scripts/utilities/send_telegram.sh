#!/usr/bin/env bash
# Universal Telegram notification for Hospital Database Backup
# Usage: ./send_telegram.sh "CRITICAL" "Title" "Message body"
# Requires: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in .env
# NEVER blocks critical operations — exits 0 even on failure

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Source .env directly (lightweight — don't load full config)
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a; source "${PROJECT_ROOT}/.env"; set +a
fi

SEVERITY="${1:-INFO}"
TITLE="${2:-Notification}"
MESSAGE="${3:-No details provided}"
LOG_FILE="${PROJECT_ROOT}/logs/telegram.log"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

mkdir -p "${PROJECT_ROOT}/logs"

log_tg() {
    echo "[${TIMESTAMP}] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Validate credentials
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    log_tg "SKIP: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set"
    exit 0
fi

# Format emoji by severity
case "$SEVERITY" in
    CRITICAL) EMOJI="🔴" ;;
    WARNING)  EMOJI="🟡" ;;
    INFO)     EMOJI="🟢" ;;
    *)        EMOJI="⚪" ;;
esac

# Build message (Telegram MarkdownV2 — escape special chars)
TEXT="${EMOJI} ${SEVERITY} — HospitalBackupDemo
─────────────────
📌 ${TITLE}
💬 ${MESSAGE}
🕐 ${TIMESTAMP}
🖥️ $(hostname 2>/dev/null || echo 'unknown')"

# Send with retries (max 3 attempts, 10s timeout each)
API_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
SENT=false

for attempt in 1 2 3; do
    RESPONSE=$(curl -s --max-time 10 -X POST "$API_URL" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${TEXT}" \
        -d parse_mode="" \
        2>/dev/null || echo '{"ok":false}')

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        log_tg "SENT [${SEVERITY}] ${TITLE} (attempt ${attempt})"
        SENT=true
        break
    else
        log_tg "RETRY ${attempt}/3 [${SEVERITY}] ${TITLE}"
        sleep 2
    fi
done

if [ "$SENT" = false ]; then
    log_tg "FAILED [${SEVERITY}] ${TITLE} — all 3 attempts failed"
fi

# Always exit 0 — alerting must never block operations
exit 0
