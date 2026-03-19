#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

echo "Cleaning logs older than ${LOG_RETENTION_DAYS} days..."

find "${PROJECT_ROOT}/logs" -name "*.log" -type f -mtime +${LOG_RETENTION_DAYS} -delete

echo "✓ Old logs cleaned"
ls -lh "${PROJECT_ROOT}/logs"
