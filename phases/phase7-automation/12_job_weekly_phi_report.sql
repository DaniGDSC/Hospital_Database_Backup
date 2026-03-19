-- SQL Agent Job: Weekly PHI Access Report
-- HIPAA 45 CFR 164.312(b) + 164.530(j)
-- Schedule: Every Sunday at 06:00 AM
-- Generates PHI access report and sends Telegram summary
USE msdb;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Weekly_PHI_Report')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Weekly_PHI_Report', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Weekly_PHI_Report',
    @enabled = 1,
    @description = N'Weekly PHI access report for HIPAA compliance audits',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Step 1: Generate PHI access report
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Weekly_PHI_Report',
    @step_name = N'Generate_PHI_Report',
    @step_id = 1,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_PHIAccessReport;',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2;
GO

-- Step 2: Send Telegram summary
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Weekly_PHI_Report',
    @step_name = N'Send_Telegram_Summary',
    @step_id = 2,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'
DECLARE @TotalAccesses INT;
DECLARE @DeleteCount INT;
DECLARE @AfterHoursCount INT;

SELECT @TotalAccesses = COUNT(*),
       @DeleteCount = SUM(CASE WHEN Action = ''DELETE'' THEN 1 ELSE 0 END),
       @AfterHoursCount = SUM(CASE WHEN DATEPART(HOUR, AuditDate) < 7
                                    OR DATEPART(HOUR, AuditDate) >= 19 THEN 1 ELSE 0 END)
FROM dbo.AuditLog
WHERE ActionType = ''PHI_ACCESS''
  AND AuditDate >= DATEADD(DAY, -7, SYSDATETIME());

DECLARE @Msg NVARCHAR(500) = ''Weekly PHI Report: ''
    + CAST(ISNULL(@TotalAccesses, 0) AS NVARCHAR) + '' accesses, ''
    + CAST(ISNULL(@DeleteCount, 0) AS NVARCHAR) + '' deletes, ''
    + CAST(ISNULL(@AfterHoursCount, 0) AS NVARCHAR) + '' after-hours.'';

IF OBJECT_ID(''dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
    EXEC dbo.usp_SendTelegramAlert
        @Severity = N''INFO'',
        @Title = N''Weekly PHI Report'',
        @Message = @Msg;

PRINT @Msg;
',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Sunday 06:00 AM
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Weekly_Sunday_6AM_PHI')
    EXEC sp_delete_schedule @schedule_name = N'Weekly_Sunday_6AM_PHI', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Weekly_Sunday_6AM_PHI',
    @freq_type = 8,          -- Weekly
    @freq_interval = 1,      -- Sunday
    @active_start_time = 060000; -- 06:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Weekly_PHI_Report',
    @schedule_name = N'Weekly_Sunday_6AM_PHI';
GO

PRINT '✓ SQL Agent Job: HospitalBackup_Weekly_PHI_Report';
PRINT '  Schedule: Sunday at 06:00 AM';
PRINT '  Test: EXEC sp_start_job @job_name = ''HospitalBackup_Weekly_PHI_Report'';';
GO
