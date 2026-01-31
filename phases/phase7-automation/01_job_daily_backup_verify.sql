-- Phase 7: Daily Backup Verification Job
-- Purpose: Verify integrity of latest full backup daily
-- Schedule: 01:00 AM every day
-- Target DB: msdb (for SQL Agent job creation)

USE msdb;
GO

-- Step 1: Create the stored procedure (run in HospitalBackupDemo)
PRINT 'Creating stored procedure sp_verify_last_backup...';
GO

-- Switch to target database for procedure creation
USE HospitalBackupDemo;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_verify_last_backup')
    DROP PROCEDURE sp_verify_last_backup;
GO

CREATE PROCEDURE sp_verify_last_backup
    @NotifyEmail NVARCHAR(MAX) = 'dba@hospital.local'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BackupFile NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @Status NVARCHAR(50);
    DECLARE @RestoreDate DATETIME;
    DECLARE @BackupSize BIGINT;

    BEGIN TRY
        -- Find the latest full backup file
        SELECT TOP 1
            @BackupFile = physical_device_name,
            @RestoreDate = backup_start_date,
            @BackupSize = backup_size
        FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupmediafamily bm ON bs.media_set_id = bm.media_set_id
        WHERE bs.database_name = 'HospitalBackupDemo'
            AND bs.type = 'D' -- Full backup
        ORDER BY bs.backup_start_date DESC;

        IF @BackupFile IS NULL
        BEGIN
            SET @Status = 'FAILED';
            SET @ErrorMessage = 'No full backup file found in backup history';
            RAISERROR(@ErrorMessage, 16, 1);
        END

        PRINT CONCAT('Verifying backup: ', @BackupFile);
        PRINT CONCAT('Backup date: ', @RestoreDate);
        PRINT CONCAT('Backup size: ', @BackupSize, ' bytes');

        -- Verify backup integrity
        DECLARE @VerifyResult TABLE (
            BackupSetId INT,
            BackupSetName NVARCHAR(256),
            BackupSetDescription NVARCHAR(256),
            BackupSetType CHAR(1),
            ExpirationDate DATETIME,
            Compressed BIT,
            Position INT,
            DeviceType NVARCHAR(50),
            UserName NVARCHAR(128),
            ServerName NVARCHAR(128),
            DatabaseName NVARCHAR(128),
            DatabaseVersion INT,
            DatabaseCreationDate DATETIME,
            BackupStartDate DATETIME,
            BackupFinishDate DATETIME,
            DifferentialBaseLSN NUMERIC(25,0),
            DifferentialBaseName NVARCHAR(128),
            IsSnapshot BIT,
            IsCopy BIT,
            HasBackupChecksums BIT,
            IsDamaged BIT,
            BeginsLogChain BIT,
            HasIncompleteMetaData BIT,
            IsForceOffline BIT,
            StandbyRecoveryMode BIT,
            IsBackupEncrypted BIT
        );

        INSERT INTO @VerifyResult
        RESTORE HEADERONLY FROM DISK = @BackupFile;

        -- Check if backup is damaged
        IF EXISTS (SELECT 1 FROM @VerifyResult WHERE IsDamaged = 1)
        BEGIN
            SET @Status = 'DAMAGED';
            SET @ErrorMessage = 'RESTORE HEADERONLY indicates backup file is damaged!';
            RAISERROR(@ErrorMessage, 16, 1);
        END
        ELSE
        BEGIN
            SET @Status = 'VERIFIED';
            PRINT 'Backup file passed RESTORE HEADERONLY verification';
        END

        -- Log result to BackupHistory
        INSERT INTO dbo.BackupHistory 
        (BackupType, BackupDate, BackupSize, BackupFile, VerificationStatus, VerificationDate)
        VALUES 
        ('FULL_VERIFY', GETDATE(), @BackupSize, @BackupFile, @Status, GETDATE());

        PRINT CONCAT('Status: ', @Status);
        PRINT 'Daily backup verification completed successfully';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT CONCAT('ERROR: ', @ErrorMessage);
        
        -- Log error
        INSERT INTO dbo.SystemConfiguration (ConfigKey, ConfigValue, ConfigDescription, LastUpdated)
        VALUES ('BACKUP_VERIFY_ERROR', @ErrorMessage, 'Daily backup verification failed', GETDATE());

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'Stored procedure sp_verify_last_backup created successfully';
GO

-- Step 2: Create the SQL Agent Job (run in msdb)
USE msdb;
GO

-- Check if job already exists
IF EXISTS (SELECT job_id FROM sysjobs WHERE name = N'HospitalBackup_Daily_Verify')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Daily_Verify', @delete_unused_schedule = 1;
GO

-- Create Job
EXEC sp_add_job 
    @job_name = N'HospitalBackup_Daily_Verify',
    @enabled = 1,
    @description = N'Daily verification of latest full backup integrity',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Add Job Step
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Daily_Verify',
    @step_name = N'Verify_Backup',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC sp_verify_last_backup @NotifyEmail = ''dba@hospital.local'';',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create Schedule (1:00 AM every day)
EXEC sp_add_schedule
    @schedule_name = N'Daily_1AM',
    @freq_type = 4, -- Daily
    @freq_interval = 1,
    @active_start_time = 010000; -- 01:00 AM
GO

-- Attach Schedule to Job
EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Daily_Verify',
    @schedule_name = N'Daily_1AM';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Daily_Verify';
PRINT 'Schedule: Daily at 01:00 AM';
PRINT 'Test the job: EXEC sp_start_job @job_name = ''HospitalBackup_Daily_Verify'';';
GO
