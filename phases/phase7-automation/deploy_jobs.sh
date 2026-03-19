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

declare -a JOB_SCRIPTS=(
    "01_job_daily_backup_verify.sql"
    "02_job_weekly_recovery_drill.sql"
    "04_job_hourly_log_backup_check.sql"
    "05_job_daily_backup_alert.sql"
    "06_job_monthly_encryption_check.sql"
)

PHASE7_DIR="${PROJECT_ROOT}/phases/phase7-automation"

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

# Step 3: Display deployed jobs dynamically from SQL Agent
echo "=== Deployed Automation Jobs ==="
echo ""

JOB_SUMMARY_QUERY="
USE msdb;
SELECT
    j.name AS JobName,
    j.description AS Description,
    CASE j.enabled WHEN 1 THEN 'Enabled' ELSE 'Disabled' END AS Status,
    CONVERT(VARCHAR, j.date_created, 120) AS Created
FROM sysjobs j
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY j.name;
"

echo "$JOB_SUMMARY_QUERY" | sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C 2>/dev/null || {
    echo "  (Could not query job list — SQL Agent may not be accessible)"
}

echo ""
echo "To manually test a job:"
echo "  EXEC msdb.dbo.sp_start_job @job_name = N'<job_name>';"
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
