-- Phase 7: Weekly Recovery Drill Job
-- Purpose: Test recovery capability by restoring to alternate test database
-- Schedule: Sunday 02:00 AM every week
-- Target DB: msdb (for SQL Agent job creation)

USE msdb;
GO

-- Step 1: Create the stored procedure (run in HospitalBackupDemo)
PRINT 'Creating stored procedure usp_TestFullRestore...';
GO

USE HospitalBackupDemo;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_TestFullRestore')
    DROP PROCEDURE usp_TestFullRestore;
GO

CREATE PROCEDURE usp_TestFullRestore
    @TestDBName NVARCHAR(256) = NULL,
    @CleanupOldDrills BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BackupFile NVARCHAR(MAX);
    DECLARE @DiffBackupFile NVARCHAR(MAX);
    DECLARE @LogBackupFile NVARCHAR(MAX);
    DECLARE @RestoreDate DATETIME;
    DECLARE @SQLCmd NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @SourceDBName NVARCHAR(128) = 'HospitalBackupDemo';
    DECLARE @TestDB NVARCHAR(256);
    DECLARE @RowCountProd INT;
    DECLARE @RowCountTest INT;
    DECLARE @DataFile NVARCHAR(MAX);
    DECLARE @LogFile NVARCHAR(MAX);

    BEGIN TRY
        -- Generate test database name with timestamp
        IF @TestDBName IS NULL
            SET @TestDB = CONCAT('HospitalBackupDemo_RecoveryTest_', FORMAT(GETDATE(), 'yyyyMMdd_HHmmss'))
        ELSE
            SET @TestDB = @TestDBName;

        PRINT CONCAT('Starting weekly recovery drill to: ', @TestDB);

        -- Get latest full backup
        SELECT TOP 1
            @BackupFile = physical_device_name,
            @RestoreDate = backup_start_date
        FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupmediafamily bm ON bs.media_set_id = bm.media_set_id
        WHERE bs.database_name = @SourceDBName
            AND bs.type = 'D' -- Full backup
        ORDER BY bs.backup_start_date DESC;

        IF @BackupFile IS NULL
        BEGIN
            RAISERROR('No full backup found', 16, 1);
        END

        PRINT CONCAT('Using backup file: ', @BackupFile);
        PRINT CONCAT('Backup date: ', @RestoreDate);

        -- Get latest differential backup if exists
        SELECT TOP 1
            @DiffBackupFile = physical_device_name
        FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupmediafamily bm ON bs.media_set_id = bm.media_set_id
        WHERE bs.database_name = @SourceDBName
            AND bs.type = 'I' -- Differential backup
            AND bs.backup_start_date > @RestoreDate
        ORDER BY bs.backup_start_date DESC;

        -- Get latest log backups if exist
        IF @DiffBackupFile IS NOT NULL
        BEGIN
            SELECT TOP 1
                @LogBackupFile = physical_device_name
            FROM msdb.dbo.backupset bs
            JOIN msdb.dbo.backupmediafamily bm ON bs.media_set_id = bm.media_set_id
            WHERE bs.database_name = @SourceDBName
                AND bs.type = 'L' -- Log backup
                AND bs.backup_start_date > (
                    SELECT MAX(backup_start_date) 
                    FROM msdb.dbo.backupset 
                    WHERE database_name = @SourceDBName AND type = 'I'
                )
            ORDER BY bs.backup_start_date DESC;
        END

        -- Define file locations
        SET @DataFile = CONCAT('/var/opt/mssql/data/', @TestDB, '.mdf');
        SET @LogFile = CONCAT('/var/opt/mssql/data/', @TestDB, '_log.ldf');

        -- Step 1: Delete old recovery drill databases (older than 7 days)
        IF @CleanupOldDrills = 1
        BEGIN
            PRINT 'Cleaning up old recovery drill databases...';
            DECLARE @OldTestDB NVARCHAR(128);
            DECLARE cur_old_dbs CURSOR FOR
                SELECT name FROM sys.databases 
                WHERE name LIKE 'HospitalBackupDemo_RecoveryTest_%'
                AND create_date < DATEADD(DAY, -7, GETDATE());
            
            OPEN cur_old_dbs;
            FETCH NEXT FROM cur_old_dbs INTO @OldTestDB;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @SQLCmd = CONCAT('ALTER DATABASE [', @OldTestDB, '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                    DROP DATABASE [', @OldTestDB, '];');
                EXEC sp_executesql @SQLCmd;
                PRINT CONCAT('Deleted old test database: ', @OldTestDB);
                FETCH NEXT FROM cur_old_dbs INTO @OldTestDB;
            END
            CLOSE cur_old_dbs;
            DEALLOCATE cur_old_dbs;
        END

        -- Step 2: Restore full backup
        PRINT 'Restoring full backup...';
        SET @SQLCmd = CONCAT(
            'RESTORE DATABASE [', @TestDB, '] FROM DISK = ''', @BackupFile, '''
            WITH REPLACE,
                 MOVE ''HospitalBackupDemo'' TO ''', @DataFile, ''',
                 MOVE ''HospitalBackupDemo_log'' TO ''', @LogFile, ''',
                 NORECOVERY;'
        );
        EXEC sp_executesql @SQLCmd;
        PRINT 'Full backup restored successfully';

        -- Step 3: Restore differential if available
        IF @DiffBackupFile IS NOT NULL
        BEGIN
            PRINT 'Restoring differential backup...';
            SET @SQLCmd = CONCAT(
                'RESTORE DATABASE [', @TestDB, '] FROM DISK = ''', @DiffBackupFile, '''
                WITH NORECOVERY;'
            );
            EXEC sp_executesql @SQLCmd;
            PRINT 'Differential backup restored successfully';
        END

        -- Step 4: Restore log if available
        IF @LogBackupFile IS NOT NULL
        BEGIN
            PRINT 'Restoring transaction log...';
            SET @SQLCmd = CONCAT(
                'RESTORE LOG [', @TestDB, '] FROM DISK = ''', @LogBackupFile, '''
                WITH RECOVERY;'
            );
            EXEC sp_executesql @SQLCmd;
            PRINT 'Transaction log restored successfully';
        END
        ELSE
        BEGIN
            -- Recovery if no logs
            SET @SQLCmd = CONCAT('RESTORE DATABASE [', @TestDB, '] WITH RECOVERY;');
            EXEC sp_executesql @SQLCmd;
        END

        -- Step 5: Validate restored database
        PRINT 'Validating restored database...';
        SET @SQLCmd = CONCAT('DBCC CHECKDB([', @TestDB, ']) WITH NO_INFOMSGS;');
        EXEC sp_executesql @SQLCmd;
        PRINT 'Database integrity check passed';

        -- Step 6: Compare row counts
        SET @SQLCmd = CONCAT('SELECT COUNT(*) FROM [', @SourceDBName, '].dbo.Patients');
        EXEC sp_executesql @SQLCmd, N'@RowCount INT OUTPUT', @RowCountProd OUTPUT;

        SET @SQLCmd = CONCAT('SELECT COUNT(*) FROM [', @TestDB, '].dbo.Patients');
        EXEC sp_executesql @SQLCmd, N'@RowCount INT OUTPUT', @RowCountTest OUTPUT;

        IF @RowCountProd = @RowCountTest
        BEGIN
            PRINT CONCAT('Row count validation passed: ', @RowCountProd, ' rows');
        END
        ELSE
        BEGIN
            RAISERROR(CONCAT('Row count mismatch! Prod: ', @RowCountProd, ', Test: ', @RowCountTest), 16, 1);
        END

        -- Step 7: Log success
        INSERT INTO dbo.BackupHistory
        (BackupType, BackupStartDate, BackupFileName, BackupLocation, BackupStatus, VerificationStatus, VerificationDate)
        VALUES
        ('Full', GETDATE(), @TestDB, @TestDB, 'Completed', 'Verified', GETDATE());

        PRINT CONCAT('Recovery drill completed successfully!');
        PRINT CONCAT('Test database created: ', @TestDB);
        PRINT CONCAT('Keep for review, will be auto-deleted after 7 days');

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT CONCAT('ERROR: ', @ErrorMessage);
        
        -- Log failure
        INSERT INTO dbo.SystemConfiguration (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
        VALUES ('RECOVERY_DRILL_ERROR', @ErrorMessage, 'Backup', 'Weekly recovery drill failed', GETDATE());

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'Stored procedure usp_TestFullRestore created successfully';
GO

-- Step 2: Create the SQL Agent Job (run in msdb)
USE msdb;
GO

IF EXISTS (SELECT job_id FROM sysjobs WHERE name = N'HospitalBackup_Weekly_RecoveryDrill')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Weekly_RecoveryDrill', @delete_unused_schedule = 1;
GO

EXEC sp_add_job 
    @job_name = N'HospitalBackup_Weekly_RecoveryDrill',
    @enabled = 1,
    @description = N'Weekly recovery drill - restore backup to test database',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Weekly_RecoveryDrill',
    @step_name = N'Run_Recovery_Drill',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC usp_TestFullRestore @CleanupOldDrills = 1;',
    @retry_attempts = 1,
    @retry_interval = 10,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create Schedule (Sunday 02:00 AM)
-- freq_type: 4 = Daily, freq_subday_type: 1 = Once per day, freq_recurrence_factor: 1 = Weekly
-- Use freq_interval = 1 for Sunday
IF EXISTS (SELECT schedule_id FROM sysschedules WHERE name = N'Weekly_Sunday_2AM')
    EXEC sp_delete_schedule @schedule_name = N'Weekly_Sunday_2AM', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Weekly_Sunday_2AM',
    @freq_type = 8, -- Weekly
    @freq_interval = 1, -- Sunday
    @active_start_time = 020000; -- 02:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Weekly_RecoveryDrill',
    @schedule_name = N'Weekly_Sunday_2AM';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Weekly_RecoveryDrill';
PRINT 'Schedule: Sunday at 02:00 AM';
PRINT 'Test the job: EXEC sp_start_job @job_name = ''HospitalBackup_Weekly_RecoveryDrill'';';
GO
