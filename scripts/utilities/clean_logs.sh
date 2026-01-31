#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

echo "Cleaning old logs..."

# Delete logs older than 30 days
find "${PROJECT_ROOT}/logs" -name "*.log" -type f -mtime +30 -delete

echo "✓ Old logs cleaned"
ls -lh "${PROJECT_ROOT}/logs"
