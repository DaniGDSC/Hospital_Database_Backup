-- Phase 7: Job Verification and Testing Guide
-- Run these queries to verify all automation jobs are created and working

USE msdb;
GO

PRINT '===== PHASE 7 JOB VERIFICATION GUIDE =====';
PRINT '';

-- =============================================================================
-- SECTION 1: Verify All Jobs Created
-- =============================================================================

PRINT 'SECTION 1: Verify Job Creation';
PRINT '==============================';
PRINT '';

DECLARE @JobCount INT;
SELECT @JobCount = COUNT(*)
FROM sysjobs
WHERE name LIKE 'HospitalBackup_%';

PRINT CONCAT('Total HospitalBackup jobs found: ', @JobCount);
PRINT '';

SELECT 
    name AS [Job Name],
    enabled AS [Enabled],
    date_created AS [Created Date],
    date_modified AS [Last Modified]
FROM sysjobs
WHERE name LIKE 'HospitalBackup_%'
ORDER BY name;

PRINT '';

-- =============================================================================
-- SECTION 2: Verify Job Schedules
-- =============================================================================

PRINT 'SECTION 2: Verify Job Schedules';
PRINT '===============================';
PRINT '';

SELECT 
    j.name AS [Job Name],
    s.name AS [Schedule Name],
    CASE s.freq_type
        WHEN 1 THEN 'Once'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly (relative)'
        WHEN 64 THEN 'When Agent starts'
        WHEN 128 THEN 'When CPU idle'
        ELSE CONCAT('Type ', s.freq_type)
    END AS [Frequency],
    CASE
        WHEN s.freq_type = 4 THEN CONCAT('Daily at ', FORMAT(s.active_start_time, '00:00'))
        WHEN s.freq_type = 8 THEN CASE s.freq_interval
            WHEN 1 THEN 'Sunday'
            WHEN 2 THEN 'Monday'
            WHEN 4 THEN 'Tuesday'
            WHEN 8 THEN 'Wednesday'
            WHEN 16 THEN 'Thursday'
            WHEN 32 THEN 'Friday'
            WHEN 64 THEN 'Saturday'
            ELSE CONCAT('Day ', s.freq_interval)
        END
        WHEN s.freq_type = 16 THEN CONCAT('Day ', s.freq_interval, ' of month')
        ELSE 'See schedule details'
    END AS [Schedule Details],
    s.enabled AS [Enabled]
FROM sysjobs j
JOIN sysjobschedules js ON j.job_id = js.job_id
JOIN sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY j.name;

PRINT '';

-- =============================================================================
-- SECTION 3: Verify Job Steps
-- =============================================================================

PRINT 'SECTION 3: Verify Job Steps';
PRINT '============================';
PRINT '';

SELECT 
    j.name AS [Job Name],
    js.step_id AS [Step],
    js.step_name AS [Step Name],
    js.subsystem AS [Subsystem],
    SUBSTRING(js.command, 1, 80) AS [Command (truncated)]
FROM sysjobs j
JOIN sysjobsteps js ON j.job_id = js.job_id
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY j.name, js.step_id;

PRINT '';

-- =============================================================================
-- SECTION 4: Recent Job History (Last 10 executions)
-- =============================================================================

PRINT 'SECTION 4: Recent Job Execution History';
PRINT '========================================';
PRINT '';

SELECT TOP 50
    j.name AS [Job Name],
    CONCAT(
        SUBSTRING(h.run_date, 1, 4), '-',
        SUBSTRING(h.run_date, 5, 2), '-',
        SUBSTRING(h.run_date, 7, 2), ' ',
        SUBSTRING(h.run_time, 1, 2), ':',
        SUBSTRING(h.run_time, 3, 2), ':',
        SUBSTRING(h.run_time, 5, 2)
    ) AS [Run Time],
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
    END AS [Status],
    h.message AS [Message]
FROM sysjobhistory h
JOIN sysjobs j ON h.job_id = j.job_id
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY h.run_date DESC, h.run_time DESC;

PRINT '';

-- =============================================================================
-- SECTION 5: Test Job Execution
-- =============================================================================

PRINT 'SECTION 5: Manual Job Testing Instructions';
PRINT '==========================================';
PRINT '';
PRINT 'To manually test a job, execute in a new query window:';
PRINT '';
PRINT '-- Test Daily Backup Verification';
PRINT 'EXEC sp_start_job @job_name = ''HospitalBackup_Daily_Verify'';';
PRINT 'WAITFOR DELAY ''00:00:05'';';
PRINT '';
PRINT '-- Test Weekly Recovery Drill (WARNING: Creates test database)';
PRINT 'EXEC sp_start_job @job_name = ''HospitalBackup_Weekly_RecoveryDrill'';';
PRINT 'WAITFOR DELAY ''00:00:10'';';
PRINT '';
PRINT '-- Test Hourly Log Backup Validation';
PRINT 'EXEC sp_start_job @job_name = ''HospitalBackup_Hourly_LogChain'';';
PRINT 'WAITFOR DELAY ''00:00:05'';';
PRINT '';
PRINT '-- Test Daily Backup Alert';
PRINT 'EXEC sp_start_job @job_name = ''HospitalBackup_Daily_Alert'';';
PRINT 'WAITFOR DELAY ''00:00:05'';';
PRINT '';
PRINT '-- Test Monthly Encryption Check';
PRINT 'EXEC sp_start_job @job_name = ''HospitalBackup_Monthly_EncryptionCheck'';';
PRINT 'WAITFOR DELAY ''00:00:05'';';
PRINT '';

PRINT 'After executing a job test, query the results:';
PRINT 'SELECT TOP 10 * FROM HospitalBackupDemo.dbo.SystemConfiguration ORDER BY LastUpdated DESC;';
PRINT 'SELECT TOP 10 * FROM HospitalBackupDemo.dbo.BackupHistory ORDER BY VerificationDate DESC;';
PRINT '';

-- =============================================================================
-- SECTION 6: Check for Stored Procedures
-- =============================================================================

PRINT 'SECTION 6: Verify Stored Procedures Exist';
PRINT '=========================================';
PRINT '';

USE HospitalBackupDemo;
GO

SELECT 
    name AS [Procedure Name],
    create_date AS [Created],
    modify_date AS [Modified]
FROM sys.procedures
WHERE name IN (
    'sp_verify_last_backup',
    'sp_test_full_restore',
    'sp_validate_log_backup_chain',
    'sp_alert_backup_failure',
    'sp_check_encryption_status'
)
ORDER BY name;

PRINT '';

-- =============================================================================
-- SECTION 7: Verify Backup History Entries
-- =============================================================================

PRINT 'SECTION 7: Check Automation Logging (BackupHistory)';
PRINT '==================================================';
PRINT '';

SELECT TOP 20
    BackupType,
    BackupDate,
    VerificationStatus,
    VerificationDate,
    BackupFile
FROM dbo.BackupHistory
WHERE BackupType IN ('FULL_VERIFY', 'RECOVERY_DRILL_SUCCESS', 'LOG_CHAIN_VERIFY', 'BACKUP_ALERT_CHECK', 'ENCRYPTION_CHECK')
ORDER BY VerificationDate DESC;

PRINT '';

-- =============================================================================
-- SECTION 8: Check Alerts and Errors
-- =============================================================================

PRINT 'SECTION 8: Recent Automation Alerts and Errors';
PRINT '=============================================';
PRINT '';

SELECT TOP 20
    ConfigKey,
    ConfigValue,
    ConfigDescription,
    LastUpdated
FROM dbo.SystemConfiguration
WHERE ConfigKey IN (
    'BACKUP_VERIFY_ERROR',
    'RECOVERY_DRILL_ERROR',
    'LOG_BACKUP_ERROR',
    'BACKUP_ALERT_FULL',
    'BACKUP_ALERT_LOG',
    'ENCRYPTION_TDE_STATUS',
    'ENCRYPTION_CERT_STATUS',
    'ENCRYPTION_CERT_EXPIRY',
    'ENCRYPTION_SYMKEY_STATUS'
)
ORDER BY LastUpdated DESC;

PRINT '';

-- =============================================================================
-- SUMMARY
-- =============================================================================

PRINT '';
PRINT '===== VERIFICATION COMPLETE =====';
PRINT '';
PRINT 'What to Check:';
PRINT '  ✓ All 5 jobs appear in SECTION 1';
PRINT '  ✓ All jobs have correct schedules in SECTION 2';
PRINT '  ✓ Job steps are correctly configured in SECTION 3';
PRINT '  ✓ Test a job manually using SECTION 5 instructions';
PRINT '  ✓ Verify stored procedures exist in SECTION 6';
PRINT '  ✓ Review automation logs in SECTIONS 7 & 8';
PRINT '';
PRINT 'Expected Jobs:';
PRINT '  1. HospitalBackup_Daily_Verify (01:00 AM daily)';
PRINT '  2. HospitalBackup_Weekly_RecoveryDrill (Sunday 02:00 AM)';
PRINT '  3. HospitalBackup_Hourly_LogChain (every hour)';
PRINT '  4. HospitalBackup_Daily_Alert (06:00 AM daily)';
PRINT '  5. HospitalBackup_Monthly_EncryptionCheck (15th at 22:00)';
PRINT '';

GO
