#!/bin/bash
# Load configuration and secrets for Hospital Backup Project

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

# Source .env first (secrets) — before project.conf so env vars are available
ENV_FILE="${PROJECT_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Source project configuration
CONFIG_FILE="${PROJECT_ROOT}/config/project.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"

    # Load environment-specific config if exists
    ENV=${ENV:-"development"}
    ENV_CONFIG="${PROJECT_ROOT}/config/${ENV}.conf"
    if [ -f "$ENV_CONFIG" ]; then
        source "$ENV_CONFIG"
    fi
else
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Shared ANSI color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Build connection string with explicit port handling
SERVER_CONN="${SQL_SERVER}"
if [[ ! "$SERVER_CONN" =~ , ]]; then
    SERVER_CONN="${SQL_SERVER},${SQL_PORT}"
fi

# Validate required secrets are set (masked output — never print values)
validate_secrets() {
    local missing=0
    local required_vars=(
        SQL_PASSWORD
        MASTER_KEY_PASSWORD
        CERT_BACKUP_PASSWORD
        APP_RW_PASSWORD
        APP_RO_PASSWORD
        APP_BILLING_PASSWORD
        APP_AUDIT_PASSWORD
    )

    echo -e "${CYAN}Validating required secrets...${NC}"
    for var_name in "${required_vars[@]}"; do
        if [ -z "${!var_name:-}" ]; then
            echo -e "  ${RED}MISSING${NC}: ${var_name}"
            missing=$((missing + 1))
        else
            echo -e "  ${GREEN}SET${NC}:     ${var_name}"
        fi
    done

    if [ $missing -gt 0 ]; then
        echo ""
        echo -e "${RED}ERROR: ${missing} required secret(s) not set.${NC}"
        echo "Set them in .env or export as environment variables."
        echo "See .env.example for the full list."
        return 1
    fi

    echo -e "${GREEN}✓ All required secrets validated${NC}"
    return 0
}

# Export all variables
export PROJECT_NAME PROJECT_CODE AUTHOR STUDENT_ID VERSION
export SQL_SERVER SQL_PORT SQL_USER SQL_PASSWORD DATABASE_NAME
export BACKUP_ROOT BACKUP_FULL_DIR BACKUP_DIFF_DIR BACKUP_LOG_DIR
export S3_BUCKET_NAME S3_REGION AWS_PROFILE
export S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY
export LOCAL_RETENTION_DAYS S3_RETENTION_DAYS LOG_BACKUP_RETENTION_HOURS
export RTO_HOURS RPO_HOURS
export NOTIFY_EMAIL SMTP_SERVER SMTP_PORT SMTP_PASSWORD
export LOG_LEVEL LOG_RETENTION_DAYS
export CERT_BACKUP_DIR CERT_BACKUP_PASSWORD MASTER_KEY_PASSWORD CERT_S3_ENCRYPTION_KEY AUDIT_EXPORT_PASSWORD
export APP_RW_PASSWORD APP_RO_PASSWORD APP_BILLING_PASSWORD APP_AUDIT_PASSWORD
export ENV
export RED GREEN YELLOW CYAN BLUE NC
export SERVER_CONN
