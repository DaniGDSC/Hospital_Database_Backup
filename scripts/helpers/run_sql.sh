#!/bin/bash
# Run SQL script with logging — passes secrets via sqlcmd -v (never logged)

# Load configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/load_config.sh"

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

# Build sqlcmd variable args (env var name → sqlcmd variable name)
# Secrets and config values are passed to SQL scripts via -v
declare -A SQLCMD_VARS=(
    [S3_BUCKET_NAME]="S3_BUCKET_NAME"
    [S3_REGION]="S3_REGION"
    [S3_ACCESS_KEY_ID]="S3_IDENTITY"
    [S3_SECRET_ACCESS_KEY]="S3_SECRET"
    [MASTER_KEY_PASSWORD]="MASTER_KEY_PASSWORD"
    [CERT_BACKUP_PASSWORD]="CERT_BACKUP_PASSWORD"
    [APP_RW_PASSWORD]="APP_RW_PASSWORD"
    [APP_RO_PASSWORD]="APP_RO_PASSWORD"
    [APP_BILLING_PASSWORD]="APP_BILLING_PASSWORD"
    [APP_AUDIT_PASSWORD]="APP_AUDIT_PASSWORD"
)
VAR_ARGS=()
for env_var in "${!SQLCMD_VARS[@]}"; do
    if [ -n "${!env_var:-}" ]; then
        VAR_ARGS+=("-v" "${SQLCMD_VARS[$env_var]}=${!env_var}")
    fi
done

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
