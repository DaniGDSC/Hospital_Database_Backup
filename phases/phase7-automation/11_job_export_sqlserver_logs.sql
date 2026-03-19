-- Phase 7: SQL Server Log Export Job
-- Exports security/backup/error events every 15 minutes for Promtail shipping
-- Required for centralized log management (Loki)

USE msdb;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Export_SQLServer_Logs')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Export_SQLServer_Logs', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Export_SQLServer_Logs',
    @enabled = 1,
    @description = N'Export SQL Server security and error events for centralized log shipping',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Export_SQLServer_Logs',
    @step_name = N'Export_Logs',
    @step_id = 1,
    @subsystem = N'CmdExec',
    @command = N'/home/un1/project/Hospital_Database_Backup-main/scripts/utilities/export_sqlserver_logs.sh',
    @retry_attempts = 1,
    @retry_interval = 2,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Every 15 minutes
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Every_15_Minutes_LogExport')
    EXEC sp_delete_schedule @schedule_name = N'Every_15_Minutes_LogExport', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Every_15_Minutes_LogExport',
    @freq_type = 4,             -- Daily
    @freq_subday_type = 4,      -- Minutes
    @freq_subday_interval = 15, -- Every 15 minutes
    @active_start_time = 000000;
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Export_SQLServer_Logs',
    @schedule_name = N'Every_15_Minutes_LogExport';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Export_SQLServer_Logs';
PRINT 'Schedule: Every 15 minutes';
GO
