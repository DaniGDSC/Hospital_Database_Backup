-- Phase 7: Hourly Transaction Log Backup Job
-- Purpose: Create encrypted log backups hourly to local disk
-- Schedule: Every hour at top of hour

USE msdb;
GO

-- Create job (drop if exists)
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Hourly_LogBackup')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Hourly_LogBackup', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Hourly_LogBackup',
    @enabled = 1,
    @description = N'Hourly encrypted log backup to local disk',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Step: Local encrypted log backup via shared procedure
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Hourly_LogBackup',
    @step_name = N'Log_Backup_Local',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_PerformBackup @BackupType = N''LOG'';',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2; -- Quit with failure
GO

-- Schedule: Every hour at top of hour
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Hourly_TopOfHour_Backup')
    EXEC sp_delete_schedule @schedule_name = N'Hourly_TopOfHour_Backup', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Hourly_TopOfHour_Backup',
    @freq_type = 4, -- Daily
    @freq_subday_type = 4, -- Hours
    @freq_subday_interval = 1, -- Every hour
    @active_start_time = 000000; -- Start at midnight
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Hourly_LogBackup',
    @schedule_name = N'Hourly_TopOfHour_Backup';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Hourly_LogBackup';
GO
