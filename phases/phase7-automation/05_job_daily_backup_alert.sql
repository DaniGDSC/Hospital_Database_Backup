-- Phase 7: Daily Backup Failure Alert Job
-- Purpose: Alert if backup is older than 2 days
-- Schedule: 06:00 AM every day
-- Target DB: msdb (for SQL Agent job creation)

USE msdb;
GO

PRINT 'Creating stored procedure usp_AlertBackupFailure...';
GO

USE HospitalBackupDemo;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_AlertBackupFailure')
    DROP PROCEDURE usp_AlertBackupFailure;
GO

CREATE PROCEDURE usp_AlertBackupFailure
    @AlertThresholdDays INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LastFullBackupTime DATETIME;
    DECLARE @LastDiffBackupTime DATETIME;
    DECLARE @LastLogBackupTime DATETIME;
    DECLARE @DaysSinceFullBackup FLOAT;
    DECLARE @DaysSinceDiffBackup FLOAT;
    DECLARE @DaysSinceLogBackup FLOAT;
    DECLARE @AlertMessage NVARCHAR(MAX);
    DECLARE @HasAlert BIT = 0;

    BEGIN TRY
        -- Get latest backup times via shared procedure
        EXEC dbo.usp_GetBackupTimestamps
            @LastFull = @LastFullBackupTime OUTPUT,
            @LastDiff = @LastDiffBackupTime OUTPUT,
            @LastLog  = @LastLogBackupTime OUTPUT;

        -- Calculate days since last backup
        SET @DaysSinceFullBackup = DATEDIFF(DAY, @LastFullBackupTime, GETDATE());
        SET @DaysSinceDiffBackup = DATEDIFF(DAY, ISNULL(@LastDiffBackupTime, GETDATE()), GETDATE());
        SET @DaysSinceLogBackup = DATEDIFF(DAY, ISNULL(@LastLogBackupTime, GETDATE()), GETDATE());

        PRINT CONCAT('=== Backup Status Report ===');
        PRINT CONCAT('Last Full Backup: ', ISNULL(FORMAT(@LastFullBackupTime, 'yyyy-MM-dd HH:mm:ss'), 'NEVER'), ' (', @DaysSinceFullBackup, ' days ago)');
        PRINT CONCAT('Last Differential: ', ISNULL(FORMAT(@LastDiffBackupTime, 'yyyy-MM-dd HH:mm:ss'), 'NEVER'), ' (', @DaysSinceDiffBackup, ' days ago)');
        PRINT CONCAT('Last Log Backup: ', ISNULL(FORMAT(@LastLogBackupTime, 'yyyy-MM-dd HH:mm:ss'), 'NEVER'), ' (', @DaysSinceLogBackup, ' days ago)');
        PRINT CONCAT('Alert Threshold: ', @AlertThresholdDays, ' days');
        PRINT '';

        -- Check full backup
        IF @LastFullBackupTime IS NULL
        BEGIN
            SET @AlertMessage = 'CRITICAL: No full backup exists!';
            PRINT CONCAT('ALERT: ', @AlertMessage);
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('BACKUP_ALERT_FULL', @AlertMessage, 'Backup', 'Daily backup failure alert', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE IF @DaysSinceFullBackup > @AlertThresholdDays
        BEGIN
            SET @AlertMessage = CONCAT('WARNING: Full backup is ', CAST(@DaysSinceFullBackup AS INT), ' days old (threshold: ', @AlertThresholdDays, ' days)');
            PRINT CONCAT('ALERT: ', @AlertMessage);
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('BACKUP_ALERT_FULL', @AlertMessage, 'Backup', 'Daily backup failure alert', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE
        BEGIN
            PRINT 'Full backup: OK';
        END

        -- Check log backup
        IF @LastLogBackupTime IS NULL
        BEGIN
            SET @AlertMessage = 'WARNING: No log backup exists - PITR not possible';
            PRINT CONCAT('ALERT: ', @AlertMessage);
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('BACKUP_ALERT_LOG', @AlertMessage, 'Backup', 'Daily backup failure alert', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE IF @DaysSinceLogBackup > 1 -- Log backups should be more frequent
        BEGIN
            SET @AlertMessage = CONCAT('WARNING: Log backup is ', CAST(@DaysSinceLogBackup AS INT), ' days old - check log backup schedule');
            PRINT CONCAT('ALERT: ', @AlertMessage);
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('BACKUP_ALERT_LOG', @AlertMessage, 'Backup', 'Daily backup failure alert', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE
        BEGIN
            PRINT 'Log backup: OK';
        END

        -- Report final status
        IF @HasAlert = 0
        BEGIN
            PRINT '';
            PRINT 'All backup checks PASSED - no alerts generated';
            INSERT INTO dbo.BackupHistory
            (BackupType, BackupStartDate, BackupFileName, BackupLocation, BackupStatus, VerificationStatus, VerificationDate)
            VALUES
            ('Full', GETDATE(), 'All backups', 'Local Disk', 'Completed', 'Verified', GETDATE());
        END
        ELSE
        BEGIN
            PRINT '';
            PRINT 'ATTENTION: Backup alerts have been generated - review SystemConfiguration table';
            INSERT INTO dbo.BackupHistory
            (BackupType, BackupStartDate, BackupFileName, BackupLocation, BackupStatus, VerificationStatus, VerificationDate)
            VALUES
            ('Full', GETDATE(), 'All backups', 'Local Disk', 'Completed', 'Failed', GETDATE());
        END

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT CONCAT('ERROR: ', @ErrorMessage);
        
        INSERT INTO dbo.SystemConfiguration 
        (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
        VALUES ('BACKUP_ALERT_ERROR', @ErrorMessage, 'Backup', 'Daily backup failure alert job failed', GETDATE());

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'Stored procedure usp_AlertBackupFailure created successfully';
GO

-- Create the SQL Agent Job (run in msdb)
USE msdb;
GO

IF EXISTS (SELECT job_id FROM sysjobs WHERE name = N'HospitalBackup_Daily_Alert')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Daily_Alert', @delete_unused_schedule = 1;
GO

EXEC sp_add_job 
    @job_name = N'HospitalBackup_Daily_Alert',
    @enabled = 1,
    @description = N'Daily alert if backup is older than threshold',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Daily_Alert',
    @step_name = N'Check_Backup_Age',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC usp_AlertBackupFailure @AlertThresholdDays = 2;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create Schedule (6:00 AM every day)
IF EXISTS (SELECT schedule_id FROM sysschedules WHERE name = N'Daily_6AM')
    EXEC sp_delete_schedule @schedule_name = N'Daily_6AM', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Daily_6AM',
    @freq_type = 4, -- Daily
    @freq_interval = 1,
    @active_start_time = 060000; -- 06:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Daily_Alert',
    @schedule_name = N'Daily_6AM';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Daily_Alert';
PRINT 'Schedule: Daily at 06:00 AM';
PRINT 'Test the job: EXEC sp_start_job @job_name = ''HospitalBackup_Daily_Alert'';';
GO
