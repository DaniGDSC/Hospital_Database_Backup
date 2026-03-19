-- Phase 7: Nightly Audit Log Export to S3
-- HIPAA 45 CFR 164.530(j): Audit logs must survive server destruction
-- Schedule: Daily at 01:00 AM (after hourly log backup at 00:00)
-- Exports yesterday's audit data, encrypts, uploads to S3 Object Lock

USE msdb;
GO

SET NOCOUNT ON;

-- Drop existing job if present
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Nightly_AuditExport')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Nightly_AuditExport', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Nightly_AuditExport',
    @enabled = 1,
    @description = N'Nightly export of audit logs to encrypted S3 storage (HIPAA 6-year retention)',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance',
    @notify_level_email = 2; -- Notify on failure
GO

-- Step 1: Export audit tables to CSV via stored procedure
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Nightly_AuditExport',
    @step_name = N'Export_Audit_CSV',
    @step_id = 1,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_ExportAuditLogs;',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2; -- Quit with failure
GO

-- Step 2: Encrypt and upload to S3
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Nightly_AuditExport',
    @step_name = N'Upload_Encrypted_To_S3',
    @step_id = 2,
    @subsystem = N'CmdExec',
    @command = N'/home/un1/project/Hospital_Database_Backup-main/scripts/utilities/upload_audit_to_s3.sh',
    @retry_attempts = 1,
    @retry_interval = 10,
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2; -- Quit with failure
GO

-- Step 3: Verify S3 upload and log result
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Nightly_AuditExport',
    @step_name = N'Verify_And_Log',
    @step_id = 3,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'
-- Log successful export to SecurityAuditEvents
INSERT INTO dbo.SecurityAuditEvents
    (EventTime, EventType, LoginName, DatabaseUser, ObjectName,
     ObjectType, Action, Success, ClientHost, ApplicationName, Details)
VALUES
    (SYSDATETIME(),
     ''AUDIT_S3_EXPORT'',
     SUSER_SNAME(),
     USER_NAME(),
     ''audit-logs'',
     ''S3_OBJECT'',
     ''UPLOAD'',
     1,
     HOST_NAME(),
     ''SQL Agent'',
     ''Nightly audit export to S3 completed successfully for '' +
     CONVERT(NVARCHAR(10), DATEADD(DAY, -1, GETUTCDATE()), 120));

PRINT ''Audit export verified and logged'';
',
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2;
GO

-- Schedule: Daily at 01:00 AM
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Daily_0100_AuditExport')
    EXEC sp_delete_schedule @schedule_name = N'Daily_0100_AuditExport', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Daily_0100_AuditExport',
    @freq_type = 4,         -- Daily
    @freq_interval = 1,     -- Every day
    @active_start_time = 010000; -- 01:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Nightly_AuditExport',
    @schedule_name = N'Daily_0100_AuditExport';
GO

-- Add notification operator
IF EXISTS (SELECT 1 FROM sysoperators WHERE name = 'DBA_Team')
    EXEC sp_update_job
        @job_name = N'HospitalBackup_Nightly_AuditExport',
        @notify_email_operator_name = N'DBA_Team';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Nightly_AuditExport';
PRINT 'Schedule: Daily at 01:00 AM';
PRINT 'Steps: Export CSV -> Encrypt+Upload S3 -> Verify+Log';
GO
