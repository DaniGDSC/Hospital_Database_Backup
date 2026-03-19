-- Phase 7: Daily Differential Backup Job
-- Purpose: Create encrypted differential backups daily to local disk
-- Schedule: Daily (Mon-Sat) 02:00 AM

USE msdb;
GO

-- Create job (drop if exists)
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Daily_DifferentialBackup')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Daily_DifferentialBackup', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Daily_DifferentialBackup',
    @enabled = 1,
    @description = N'Daily encrypted differential backup to local disk',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Step: Local encrypted differential backup via shared procedure
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Daily_DifferentialBackup',
    @step_name = N'Differential_Backup_Local',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_PerformBackup @BackupType = N''DIFFERENTIAL'';',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2; -- Quit with failure
GO

-- Schedule: Daily at 02:00 AM (Mon-Sat)
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Daily_0200_MonSat')
    EXEC sp_delete_schedule @schedule_name = N'Daily_0200_MonSat', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Daily_0200_MonSat',
    @freq_type = 8, -- Weekly
    @freq_interval = 62, -- Mon-Sat (2+4+8+16+32 = 62)
    @active_start_time = 020000; -- 02:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Daily_DifferentialBackup',
    @schedule_name = N'Daily_0200_MonSat';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Daily_DifferentialBackup';
GO
