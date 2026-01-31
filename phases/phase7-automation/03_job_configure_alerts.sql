-- Phase 7: Create Operator and Configure Alerts (Optional - for email notifications)
-- Execute this script if you want to configure email notifications for job failures

USE msdb;
GO

PRINT 'Configuring SQL Server Agent Operator and Alerts...';
GO

-- Step 1: Create DBA Team Operator (email notifications)
IF NOT EXISTS (SELECT name FROM sysoperators WHERE name = 'DBA_Team')
BEGIN
    PRINT 'Creating operator: DBA_Team';
    EXEC sp_add_operator 
        @name = N'DBA_Team',
        @enabled = 1,
        @email_address = N'dba@hospital.local',
        @pager_address = N'dba-oncall@hospital.local';
    PRINT '✓ Operator created';
END
ELSE
BEGIN
    PRINT '✓ Operator already exists: DBA_Team';
END
GO

-- Step 2: Configure mail profile (requires xp_cmdshell or SMTP configuration)
-- Note: This is typically configured at the Windows/Linux level, not in SQL Server
PRINT '';
PRINT 'Email Configuration Notes:';
PRINT '  • Email notifications require SMTP server configuration';
PRINT '  • Configure in: Management Studio → Management → Database Mail';
PRINT '  • Or via: sp_configure ''Database Mail XPs'', 1;';
PRINT '  • Test mail: EXEC sp_send_dbmail @subject=''Test'', @body=''Testing'', @recipients=''dba@hospital.local'';';
GO

-- Step 3: Configure job failure notifications
-- Update jobs to notify operator on failure (already done in job creation, but can be modified here)

PRINT '';
PRINT 'Alert Configuration: Jobs are pre-configured to:';
PRINT '  • Log failures to SystemConfiguration table';
PRINT '  • Log results to BackupHistory table';
PRINT '  • Email notifications can be added via sp_update_job';
GO

PRINT '';
PRINT 'To add email notification to a job:';
PRINT 'EXEC sp_update_job';
PRINT '    @job_name = ''HospitalBackup_Daily_Alert'',';
PRINT '    @notify_level_eventlog = 2, -- Error';
PRINT '    @notify_level_email = 2,    -- Error';
PRINT '    @notify_email_operator_name = ''DBA_Team'';';
GO

PRINT '';
PRINT 'Configuration complete - Operator DBA_Team is available for job notifications';
PRINT '';
GO
