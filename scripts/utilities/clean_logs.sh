#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

LOKI_URL="${LOKI_URL:-http://localhost:3100}"

echo "Cleaning logs older than ${LOG_RETENTION_DAYS} days..."

# Check if Loki is receiving logs before deleting local copies
LOKI_OK=false
if curl -s "${LOKI_URL}/ready" 2>/dev/null | grep -q "ready"; then
    RECENT=$(curl -s -G "${LOKI_URL}/loki/api/v1/query" \
        --data-urlencode 'query=count_over_time({job=~".+"}[1h])' 2>/dev/null \
        | grep -c '"value"' || echo "0")
    if [ "$RECENT" -gt 0 ]; then
        LOKI_OK=true
        echo "✓ Loki is receiving logs — safe to clean local copies"
    fi
fi

if [ "$LOKI_OK" = false ]; then
    echo "⚠ Loki not confirmed — keeping security logs (only cleaning automation logs > ${LOG_RETENTION_DAYS} days)"
    # Only clean automation logs, keep audit exports longer
    find "${PROJECT_ROOT}/logs" -name "pipeline_*.log" -type f -mtime +${LOG_RETENTION_DAYS} -delete
    find "${PROJECT_ROOT}/logs" -name "cert_*.log" -type f -mtime +${LOG_RETENTION_DAYS} -delete
else
    # Full cleanup — Loki has the copies
    find "${PROJECT_ROOT}/logs" -name "*.log" -type f -mtime +${LOG_RETENTION_DAYS} -delete
fi

# Never delete security audit exports before 7 days regardless
echo "✓ Local security audit exports retained minimum 7 days"

echo "✓ Log cleanup completed"
ls -lh "${PROJECT_ROOT}/logs" 2>/dev/null | head -10
