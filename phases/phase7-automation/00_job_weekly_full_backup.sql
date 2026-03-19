-- Phase 7: Weekly Full Backup Job (Local + S3)
-- Purpose: Create encrypted full backups weekly to local disk and S3
-- Schedule: Weekly (Sunday) 01:30 AM

USE msdb;
GO

-- Create job (drop if exists)
IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Weekly_FullBackup')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Weekly_FullBackup', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Weekly_FullBackup',
    @enabled = 1,
    @description = N'Weekly encrypted full backup to local disk and S3',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Step 1: Local encrypted full backup via shared procedure
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Weekly_FullBackup',
    @step_name = N'Full_Backup_Local',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_PerformBackup @BackupType = N''FULL'';',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 3; -- Go to next step
GO

-- Step 2: Full encrypted backup directly to S3 (requires credential)
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Weekly_FullBackup',
    @step_name = N'Full_Backup_S3',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @credName SYSNAME = N''S3_HospitalBackupDemo'';
IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    PRINT ''Skipping S3 backup: credential not found.'';
    RETURN;
END

DECLARE @bucket NVARCHAR(200) = N''s3://hospital-backup-prod-lock/backups'';
DECLARE @fileName NVARCHAR(400) = @bucket + N''/HospitalBackupDemo_FULL_'' +
    CONVERT(CHAR(8), GETDATE(), 112) + N''_'' +
    REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''') + N''.bak'';

DECLARE @sql NVARCHAR(MAX) = N''BACKUP DATABASE HospitalBackupDemo
    TO URL = '''''' + @fileName + N''''''
    WITH CREDENTIAL = '''''' + @credName + N'''''',
         COMPRESSION, CHECKSUM,
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''''Full backup to S3 (Encrypted AES_256)'''';'';

EXEC (@sql);
PRINT ''Full backup sent to S3: '' + @fileName;
',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2; -- Quit with failure
GO

-- Schedule: Weekly Sunday at 01:30 AM
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Weekly_Sunday_0130')
    EXEC sp_delete_schedule @schedule_name = N'Weekly_Sunday_0130', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Weekly_Sunday_0130',
    @freq_type = 8, -- Weekly
    @freq_interval = 1, -- Sunday
    @active_start_time = 013000; -- 01:30 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Weekly_FullBackup',
    @schedule_name = N'Weekly_Sunday_0130';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Weekly_FullBackup';
GO
