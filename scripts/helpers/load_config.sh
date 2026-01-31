#!/bin/bash
# Load configuration file

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
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

# Export all variables
export PROJECT_NAME PROJECT_CODE AUTHOR STUDENT_ID VERSION
export SQL_SERVER SQL_PORT SQL_USER SQL_PASSWORD DATABASE_NAME
export BACKUP_ROOT BACKUP_FULL_DIR BACKUP_DIFF_DIR BACKUP_LOG_DIR
export S3_BUCKET_NAME S3_REGION AWS_PROFILE
export S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY
export LOCAL_RETENTION_DAYS S3_RETENTION_DAYS LOG_BACKUP_RETENTION_HOURS
export RTO_HOURS RPO_HOURS
export NOTIFY_EMAIL SMTP_SERVER SMTP_PORT
export LOG_LEVEL LOG_RETENTION_DAYS
export CERT_BACKUP_DIR
export ENV
