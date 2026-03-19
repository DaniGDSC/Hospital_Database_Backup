-- Phase 7: Hourly Log Backup Validation Job
-- Purpose: Validate log backup chain integrity every hour
-- Schedule: Top of every hour (00:00, 01:00, 02:00, etc.)
-- Target DB: msdb (for SQL Agent job creation)

USE msdb;
GO

PRINT 'Creating stored procedure usp_ValidateLogBackupChain...';
GO

USE HospitalBackupDemo;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_ValidateLogBackupChain')
    DROP PROCEDURE usp_ValidateLogBackupChain;
GO

CREATE PROCEDURE usp_ValidateLogBackupChain
    @AlertThresholdMinutes INT = 60
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @LastLogBackupTime DATETIME;
    DECLARE @MinutesSinceLastLog INT;
    DECLARE @LogBackupCount INT;
    DECLARE @LSNGapDetected BIT = 0;
    DECLARE @AlertMessage NVARCHAR(MAX);

    BEGIN TRY
        -- Get latest log backup time via shared procedure
        DECLARE @UnusedFull DATETIME, @UnusedDiff DATETIME;
        EXEC dbo.usp_GetBackupTimestamps
            @LastFull = @UnusedFull OUTPUT,
            @LastDiff = @UnusedDiff OUTPUT,
            @LastLog  = @LastLogBackupTime OUTPUT;

        IF @LastLogBackupTime IS NULL
        BEGIN
            PRINT 'Warning: No log backups found in history';
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('LOG_BACKUP_WARNING', 'No log backups exist', 'Backup', 'Hourly log backup validation', GETDATE());
            RETURN;
        END

        -- Calculate minutes since last log backup
        SET @MinutesSinceLastLog = DATEDIFF(MINUTE, @LastLogBackupTime, GETDATE());

        PRINT CONCAT('Last log backup: ', @LastLogBackupTime);
        PRINT CONCAT('Minutes since last backup: ', @MinutesSinceLastLog);

        -- Check if gap exceeds threshold
        IF @MinutesSinceLastLog > @AlertThresholdMinutes
        BEGIN
            SET @LSNGapDetected = 1;
            SET @AlertMessage = CONCAT(
                'LOG BACKUP CHAIN ALERT: No log backup for ', 
                @MinutesSinceLastLog, ' minutes (threshold: ', 
                @AlertThresholdMinutes, ' minutes)'
            );
            PRINT CONCAT('ERROR: ', @AlertMessage);
            
            -- Log alert
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('LOG_BACKUP_ALERT', @AlertMessage, 'Backup', 'Hourly log backup validation', GETDATE());

            RAISERROR(@AlertMessage, 16, 1);
        END

        -- Count total log backups
        SELECT @LogBackupCount = COUNT(*)
        FROM msdb.dbo.backupset
        WHERE database_name = 'HospitalBackupDemo'
            AND type = 'L'
            AND backup_start_date >= DATEADD(DAY, -1, GETDATE());

        PRINT CONCAT('Log backups in last 24 hours: ', @LogBackupCount);

        -- Validate log backup chain continuity by checking LSN sequences
        DECLARE @FirstLSN NUMERIC(25,0);
        DECLARE @LastLSN NUMERIC(25,0);
        DECLARE @LSNGap NUMERIC(25,0);

        DECLARE log_cursor CURSOR FOR
            SELECT first_lsn, last_lsn
            FROM msdb.dbo.backupset
            WHERE database_name = 'HospitalBackupDemo'
                AND type = 'L'
            ORDER BY backup_start_date DESC;

        OPEN log_cursor;
        FETCH NEXT FROM log_cursor INTO @FirstLSN, @LastLSN;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @LastLSN IS NOT NULL
            BEGIN
                IF @FirstLSN > @LastLSN
                BEGIN
                    SET @LSNGap = @FirstLSN - @LastLSN;
                    IF @LSNGap > 1
                    BEGIN
                        PRINT CONCAT('LSN Gap detected: ', @LSNGap);
                        SET @LSNGapDetected = 1;
                    END
                END
            END
            FETCH NEXT FROM log_cursor INTO @FirstLSN, @LastLSN;
        END
        CLOSE log_cursor;
        DEALLOCATE log_cursor;

        IF @LSNGapDetected = 1
        BEGIN
            RAISERROR('Log backup chain has gaps - PITR capability may be affected', 16, 1);
        END

        -- Log successful validation
        INSERT INTO dbo.BackupHistory
        (BackupType, BackupStartDate, BackupFileName, BackupLocation, BackupStatus, VerificationStatus, VerificationDate)
        VALUES
        ('Transaction Log', GETDATE(), 'Log backup chain', 'Local Disk', 'Completed', 'Verified', GETDATE());

        PRINT 'Log backup chain validation passed';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT CONCAT('ERROR: ', @ErrorMessage);

        INSERT INTO dbo.SystemConfiguration
        (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
        VALUES ('LOG_BACKUP_ERROR', @ErrorMessage, 'Backup', 'Hourly log backup validation failed', GETDATE());

        -- Telegram: log backup chain failure — RPO at risk
        IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC dbo.usp_SendTelegramAlert
                @Severity = N'CRITICAL',
                @Title = N'Log Backup Chain BROKEN',
                @Message = @ErrorMessage;

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'Stored procedure usp_ValidateLogBackupChain created successfully';
GO

-- Create the SQL Agent Job (run in msdb)
USE msdb;
GO

IF EXISTS (SELECT job_id FROM sysjobs WHERE name = N'HospitalBackup_Hourly_LogChain')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Hourly_LogChain', @delete_unused_schedule = 1;
GO

EXEC sp_add_job 
    @job_name = N'HospitalBackup_Hourly_LogChain',
    @enabled = 1,
    @description = N'Hourly validation of log backup chain continuity',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Hourly_LogChain',
    @step_name = N'Validate_Log_Chain',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC usp_ValidateLogBackupChain @AlertThresholdMinutes = 120;',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create Schedule (Every hour, top of the hour)
IF EXISTS (SELECT schedule_id FROM sysschedules WHERE name = N'Hourly_TopOfHour')
    EXEC sp_delete_schedule @schedule_name = N'Hourly_TopOfHour', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Hourly_TopOfHour',
    @freq_type = 4, -- Daily
    @freq_subday_type = 4, -- Hour
    @freq_subday_interval = 1, -- Every 1 hour
    @active_start_time = 000000; -- Starting at 00:00
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Hourly_LogChain',
    @schedule_name = N'Hourly_TopOfHour';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Hourly_LogChain';
PRINT 'Schedule: Every hour at top of the hour';
PRINT 'Test the job: EXEC sp_start_job @job_name = ''HospitalBackup_Hourly_LogChain'';';
GO
