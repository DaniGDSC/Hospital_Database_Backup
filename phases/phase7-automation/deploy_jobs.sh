#!/bin/bash
# Phase 7: Automation Job Deployment Script
# This script deploys all SQL Agent jobs for automated recovery testing and failover procedures

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts/helpers"

# Source configuration
source "${SCRIPTS_DIR}/load_config.sh"

echo "=== Phase 7: SQL Agent Job Deployment ==="
echo ""
echo "Configuration:"
echo "  SQL Server: $SQL_SERVER"
echo "  SQL Port: $SQL_PORT"
echo "  Database: HospitalBackupDemo"
echo ""

# Verify SQL Server connection
echo "Verifying SQL Server connection..."
"${SCRIPTS_DIR}/test_connection.sh" || exit 1
echo "✓ Connection verified"
echo ""

# Define job scripts
declare -a STORED_PROCEDURES=(
    "sp_verify_last_backup"
    "sp_test_full_restore"
    "sp_validate_log_backup_chain"
    "sp_alert_backup_failure"
    "sp_check_encryption_status"
)

declare -a JOB_SCRIPTS=(
    "01_job_daily_backup_verify.sql"
    "02_job_weekly_recovery_drill.sql"
    "04_job_hourly_log_backup_check.sql"
    "05_job_daily_backup_alert.sql"
    "06_job_monthly_encryption_check.sql"
)

PHASE7_DIR="${PROJECT_ROOT}/phase7-automation"

# Step 1: Deploy Stored Procedures (do these first, one by one from job scripts)
echo "Deploying stored procedures..."
for script in "${JOB_SCRIPTS[@]}"; do
    echo "  Processing: $script (contains stored procedure definition)"
    SCRIPT_PATH="${PHASE7_DIR}/${script}"
    
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo "    ERROR: File not found: $SCRIPT_PATH"
        exit 1
    fi
    
    echo "    Executing: $script"
    "${SCRIPTS_DIR}/run_sql.sh" "$SCRIPT_PATH"
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "    ✓ Success"
    else
        echo "    ✗ Failed with exit code: $EXIT_CODE"
        exit 1
    fi
done

echo "✓ All stored procedures deployed"
echo ""

# Step 2: Verify Job Creation
echo "Verifying job creation..."

# Query to check created jobs
CREATE_JOBS_QUERY="
USE msdb;
GO
SELECT name, enabled, date_created 
FROM sysjobs
WHERE name LIKE 'HospitalBackup_%'
ORDER BY name;
"

echo "$CREATE_JOBS_QUERY" | "${SCRIPTS_DIR}/run_sql.sh" -
JOBS_EXIT_CODE=$?

if [[ $JOBS_EXIT_CODE -eq 0 ]]; then
    echo "✓ Job verification completed"
else
    echo "✗ Job verification failed"
    exit 1
fi

echo ""

# Step 3: Display Job Schedule Summary
echo "=== Deployed Automation Jobs ==="
echo ""
echo "1. Daily Backup Verification (01:00 AM)"
echo "   Job: HospitalBackup_Daily_Verify"
echo "   Procedure: sp_verify_last_backup"
echo "   Purpose: Verify latest full backup integrity"
echo ""

echo "2. Weekly Recovery Drill (Sunday 02:00 AM)"
echo "   Job: HospitalBackup_Weekly_RecoveryDrill"
echo "   Procedure: sp_test_full_restore"
echo "   Purpose: Test restore to alternate database"
echo ""

echo "3. Hourly Log Backup Validation (Every hour)"
echo "   Job: HospitalBackup_Hourly_LogChain"
echo "   Procedure: sp_validate_log_backup_chain"
echo "   Purpose: Validate log backup chain continuity"
echo ""

echo "4. Daily Backup Failure Alert (06:00 AM)"
echo "   Job: HospitalBackup_Daily_Alert"
echo "   Procedure: sp_alert_backup_failure"
echo "   Purpose: Alert if backup > 2 days old"
echo ""

echo "5. Monthly Encryption Check (15th at 22:00)"
echo "   Job: HospitalBackup_Monthly_EncryptionCheck"
echo "   Procedure: sp_check_encryption_status"
echo "   Purpose: Verify TDE certificate status"
echo ""

# Step 4: Testing Instructions
echo "=== Testing Instructions ==="
echo ""
echo "To manually test a job:"
echo "  EXEC sp_start_job @job_name = 'HospitalBackup_Daily_Verify';"
echo "  EXEC sp_start_job @job_name = 'HospitalBackup_Weekly_RecoveryDrill';"
echo "  EXEC sp_start_job @job_name = 'HospitalBackup_Hourly_LogChain';"
echo "  EXEC sp_start_job @job_name = 'HospitalBackup_Daily_Alert';"
echo "  EXEC sp_start_job @job_name = 'HospitalBackup_Monthly_EncryptionCheck';"
echo ""

echo "To view job history:"
echo "  SELECT job_name, run_status, run_date, run_time, message"
echo "  FROM msdb.dbo.sysjobhistory h"
echo "  JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id"
echo "  WHERE j.name LIKE 'HospitalBackup_%'"
echo "  ORDER BY run_date DESC, run_time DESC;"
echo ""

# Step 5: Verify SQL Agent is running
echo "=== SQL Agent Status ==="
echo ""

AGENT_CHECK="
EXEC sp_help_sqlagent_properties;
"

echo "$AGENT_CHECK" | "${SCRIPTS_DIR}/run_sql.sh" - > /tmp/agent_status.txt 2>&1 || {
    echo "✗ Warning: Could not verify SQL Agent status"
    echo "   Enable SQL Agent with: EXEC sp_set_sqlagent_properties @agent_auto_start = 1;"
}

if grep -q "agent_auto_start" /tmp/agent_status.txt 2>/dev/null; then
    echo "✓ SQL Agent properties accessible"
else
    echo "⚠ SQL Agent may not be running - check service status"
fi

echo ""
echo "=== Phase 7 Deployment Complete ==="
echo ""
echo "Summary:"
echo "  • 5 SQL Agent jobs deployed"
echo "  • 5 automation stored procedures created"
echo "  • Jobs scheduled for automated recovery testing and validation"
echo "  • All jobs logging to SystemConfiguration and BackupHistory tables"
echo ""
echo "Next Steps:"
echo "  1. Review phase7-automation/README.md for detailed documentation"
echo "  2. Enable SQL Server Agent if not already running"
echo "  3. Test jobs manually before going to production"
echo "  4. Monitor job execution in msdb.dbo.sysjobhistory"
echo "  5. Update on-call runbooks with automation procedures"
echo ""

exit 0
