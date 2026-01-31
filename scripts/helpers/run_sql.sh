#!/bin/bash
# Run SQL script with logging

# Load configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/load_config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: No SQL script specified${NC}"
    echo "Usage: $0 <sql_file> [database_name]"
    exit 1
fi

SQL_FILE="$1"
DB_NAME="${2:-$DATABASE_NAME}"

# Check file exists
if [ ! -f "$SQL_FILE" ]; then
    echo -e "${RED}Error: File not found: $SQL_FILE${NC}"
    exit 1
fi

# Setup logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/logs/$(basename ${SQL_FILE%.sql})_${TIMESTAMP}.log"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Running SQL Script${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Script   : $SQL_FILE"
echo "Server   : $SQL_SERVER"
echo "Database : $DB_NAME"
echo "Log      : $LOG_FILE"
echo ""

# Build connection string with explicit port handling
SERVER_CONN="${SQL_SERVER}"
if [[ ! "$SERVER_CONN" =~ , ]]; then
    SERVER_CONN="${SQL_SERVER},${SQL_PORT}"
fi

# Run SQL
# Build optional sqlcmd variable args
VAR_ARGS=()
if [ -n "${S3_BUCKET_NAME:-}" ]; then
    VAR_ARGS+=("-v" "S3_BUCKET_NAME=${S3_BUCKET_NAME}")
fi
if [ -n "${S3_REGION:-}" ]; then
    VAR_ARGS+=("-v" "S3_REGION=${S3_REGION}")
fi
if [ -n "${S3_ACCESS_KEY_ID:-}" ]; then
    VAR_ARGS+=("-v" "S3_IDENTITY=${S3_ACCESS_KEY_ID}")
fi
if [ -n "${S3_SECRET_ACCESS_KEY:-}" ]; then
    VAR_ARGS+=("-v" "S3_SECRET=${S3_SECRET_ACCESS_KEY}")
fi

sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -d "$DB_NAME" \
        -C -i "$SQL_FILE" -o "$LOG_FILE" "${VAR_ARGS[@]}" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Success${NC}"
    echo ""
    echo "Last 20 lines of output:"
    echo "----------------------------------------"
    tail -20 "$LOG_FILE"
else
    echo -e "${RED}✗ Failed${NC}"
    echo ""
    echo "Error output:"
    echo "----------------------------------------"
    tail -50 "$LOG_FILE"
    exit 1
fi
