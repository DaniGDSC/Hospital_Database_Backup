-- Restore production DB using S3 full as base, then local differential + log chain
-- Most complete recovery path: S3 full (NORECOVERY) → diff → logs → RECOVERY
-- Requires: S3 credential, local diff/log backups intact
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Cloud-base + local-chain recovery for HospitalBackupDemo ===';

DECLARE @targetDb SYSNAME = N'HospitalBackupDemo';
DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Log.ldf';
DECLARE @fullUrl NVARCHAR(500);
DECLARE @fullFinish DATETIME;
DECLARE @diffFile NVARCHAR(500);
DECLARE @diffFinish DATETIME;
DECLARE @baseFinish DATETIME;
DECLARE @logFile NVARCHAR(500);
DECLARE @logCount INT = 0;
DECLARE @sql NVARCHAR(MAX);
DECLARE @startTime DATETIME = GETUTCDATE();

BEGIN TRY
    -- Validate S3 credential
    IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
    BEGIN
        RAISERROR('Credential %s not found. Create it before running.', 16, 1, @credName);
        RETURN;
    END

    -- Find latest FULL backup from S3
    SELECT TOP 1
        @fullUrl = bmf.physical_device_name,
        @fullFinish = bs.backup_finish_date
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type = 'D'
      AND bmf.physical_device_name LIKE 's3://%'
    ORDER BY bs.backup_finish_date DESC;

    IF @fullUrl IS NULL
    BEGIN
        RAISERROR('No S3 full backup found for HospitalBackupDemo.', 16, 1);
        RETURN;
    END

    PRINT 'S3 full backup: ' + @fullUrl + ' (' + CONVERT(NVARCHAR(30), @fullFinish, 126) + ')';

    -- Find latest DIFFERENTIAL after the full
    SELECT TOP 1
        @diffFile = bmf.physical_device_name,
        @diffFinish = bs.backup_finish_date
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type = 'I'
      AND bs.backup_start_date >= @fullFinish
    ORDER BY bs.backup_finish_date DESC;

    SET @baseFinish = ISNULL(@diffFinish, @fullFinish);

    -- Drop target DB if exists
    IF DB_ID(@targetDb) IS NOT NULL
    BEGIN
        ALTER DATABASE [HospitalBackupDemo] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [HospitalBackupDemo];
        PRINT 'Dropped existing ' + @targetDb;
    END

    -- Step 1: Restore FULL from S3 with NORECOVERY
    SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
        FROM URL = N''' + @fullUrl + N'''
        WITH CREDENTIAL = ''' + @credName + N''',
             MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
             MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
             MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
             REPLACE, NORECOVERY, STATS = 10, CHECKSUM';
    EXEC (@sql);
    PRINT '  Full restored from S3 (NORECOVERY)';

    -- Step 2: Restore DIFFERENTIAL if present
    IF @diffFile IS NOT NULL
    BEGIN
        PRINT '  Differential: ' + @diffFile + ' (' + CONVERT(NVARCHAR(30), @diffFinish, 126) + ')';
        SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
            FROM DISK = N''' + @diffFile + N'''
            WITH NORECOVERY, STATS = 10, CHECKSUM';
        EXEC (@sql);
        PRINT '  Differential restored (NORECOVERY)';
    END
    ELSE
        PRINT '  No differential found after S3 full; proceeding with logs';

    -- Step 3: Apply LOG backups after base
    DECLARE @logCursor CURSOR;
    SET @logCursor = CURSOR FAST_FORWARD FOR
        SELECT bmf.physical_device_name
        FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
        WHERE bs.database_name = 'HospitalBackupDemo'
          AND bs.type = 'L'
          AND bs.backup_start_date >= @baseFinish
        ORDER BY bs.backup_start_date;

    OPEN @logCursor;
    FETCH NEXT FROM @logCursor INTO @logFile;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @logCount = @logCount + 1;
        SET @sql = N'RESTORE LOG ' + QUOTENAME(@targetDb) + N'
            FROM DISK = N''' + @logFile + N'''
            WITH NORECOVERY, STATS = 5, CHECKSUM';
        EXEC (@sql);
        PRINT '  Log ' + CAST(@logCount AS NVARCHAR) + ': ' + @logFile;
        FETCH NEXT FROM @logCursor INTO @logFile;
    END

    CLOSE @logCursor;
    DEALLOCATE @logCursor;

    -- Step 4: Final recovery — bring online
    RESTORE DATABASE [HospitalBackupDemo] WITH RECOVERY;

    DECLARE @duration INT = DATEDIFF(SECOND, @startTime, GETUTCDATE());
    PRINT '';
    PRINT '✓ Recovery completed: HospitalBackupDemo online';
    PRINT '  Chain: S3 full + '
        + CASE WHEN @diffFile IS NOT NULL THEN '1 diff' ELSE '0 diff' END
        + ' + ' + CAST(@logCount AS NVARCHAR) + ' log(s)';
    PRINT '  Duration: ' + CAST(@duration AS NVARCHAR) + 's';

    -- Log success (database is now online, AuditLog accessible)
    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'CLOUD_CHAIN_RESTORE',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1, 'Critical',
             'Cloud-chain restore: S3 full + '
             + CASE WHEN @diffFile IS NOT NULL THEN '1 diff' ELSE '0 diff' END
             + ' + ' + CAST(@logCount AS NVARCHAR) + ' logs (' + CAST(@duration AS NVARCHAR) + 's)');
    END

    IF OBJECT_ID('HospitalBackupDemo.dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
        EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
            @Severity = N'INFO',
            @Title = N'Cloud-Chain Restore Complete',
            @Message = N'HospitalBackupDemo restored and online';

END TRY
BEGIN CATCH
    DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
    PRINT '✗ CLOUD-CHAIN RESTORE FAILED: ' + @err;

    -- Cannot log to AuditLog if HospitalBackupDemo is in RESTORING state
    -- Use Telegram as primary alert channel
    BEGIN TRY
        IF OBJECT_ID('HospitalBackupDemo.dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
                @Severity = N'CRITICAL',
                @Title = N'Cloud-Chain Restore FAILED',
                @Message = @err;
    END TRY
    BEGIN CATCH
        PRINT '  (Telegram alert also failed — database may be in RESTORING state)';
    END CATCH

    RAISERROR('Cloud-chain restore failed: %s', 16, 1, @err);
END CATCH;
GO
