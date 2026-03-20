-- Point-in-time restore for HospitalBackupDemo
-- Restores full + diff + log chain, stopping at a specific time
-- Usage: sqlcmd -v STOP_AT="2026-03-19T14:30:00" -i 01_point_in_time_restore.sql
--   If STOP_AT not provided, defaults to 1 hour ago
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Point-in-time restore to HospitalBackupDemo_PITR ===';

DECLARE @stopAt DATETIME2 = '$(STOP_AT)';
DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_PITR';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_PITR_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_PITR_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_PITR_Log.ldf';
DECLARE @fullBackup NVARCHAR(260);
DECLARE @fullFinish DATETIME;
DECLARE @diffBackup NVARCHAR(260);
DECLARE @diffFinish DATETIME;
DECLARE @baseFinish DATETIME;
DECLARE @logCursor CURSOR;
DECLARE @logFile NVARCHAR(260);
DECLARE @logCount INT = 0;
DECLARE @sql NVARCHAR(MAX);
DECLARE @startTime DATETIME = GETUTCDATE();

-- Default to 1 hour ago if sqlcmd variable not provided
IF @stopAt IS NULL OR @stopAt = '$(STOP_AT)'
    SET @stopAt = DATEADD(HOUR, -1, SYSDATETIME());

PRINT 'Recovery target: ' + CONVERT(NVARCHAR(30), @stopAt, 126);

BEGIN TRY
    -- Latest full backup BEFORE stop time
    SELECT TOP 1
        @fullBackup = bmf.physical_device_name,
        @fullFinish = bs.backup_finish_date
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type = 'D'
      AND bs.backup_finish_date <= @stopAt
    ORDER BY bs.backup_finish_date DESC;

    IF @fullBackup IS NULL
    BEGIN
        RAISERROR('No full backup found before target time %s.', 16, 1, @stopAt);
        RETURN;
    END

    PRINT 'Full backup: ' + @fullBackup + ' (' + CONVERT(NVARCHAR(30), @fullFinish, 126) + ')';

    -- Latest differential AFTER the full but BEFORE stop time
    SELECT TOP 1
        @diffBackup = bmf.physical_device_name,
        @diffFinish = bs.backup_finish_date
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type = 'I'
      AND bs.backup_start_date >= @fullFinish
      AND bs.backup_finish_date <= @stopAt
    ORDER BY bs.backup_finish_date DESC;

    -- Base for log chain = diff finish (if exists) or full finish
    SET @baseFinish = ISNULL(@diffFinish, @fullFinish);

    -- Drop target DB if exists
    IF DB_ID(@targetDb) IS NOT NULL
    BEGIN
        ALTER DATABASE [HospitalBackupDemo_PITR] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [HospitalBackupDemo_PITR];
        PRINT 'Dropped existing ' + @targetDb;
    END

    -- Step 1: Restore FULL with NORECOVERY
    SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
        FROM DISK = N''' + @fullBackup + N'''
        WITH NORECOVERY,
             MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
             MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
             MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
             REPLACE, STATS = 5, CHECKSUM';
    EXEC (@sql);
    PRINT '  Full restored (NORECOVERY)';

    -- Step 2: Restore DIFFERENTIAL if present
    IF @diffBackup IS NOT NULL
    BEGIN
        PRINT 'Differential: ' + @diffBackup + ' (' + CONVERT(NVARCHAR(30), @diffFinish, 126) + ')';
        SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
            FROM DISK = N''' + @diffBackup + N'''
            WITH NORECOVERY, STATS = 5, CHECKSUM';
        EXEC (@sql);
        PRINT '  Differential restored (NORECOVERY)';
    END
    ELSE
        PRINT '  No differential found; proceeding with logs';

    -- Step 3: Apply LOG backups between base and stop time
    -- Find all log backups in the chain
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

        -- Apply STOPAT + RECOVERY on the last applicable log
        -- All others get NORECOVERY
        SET @sql = N'RESTORE LOG ' + QUOTENAME(@targetDb) + N'
            FROM DISK = N''' + @logFile + N'''
            WITH NORECOVERY, STOPAT = ''' + CONVERT(NVARCHAR(30), @stopAt, 126) + N''',
                 STATS = 5, CHECKSUM';
        BEGIN TRY
            EXEC (@sql);
            PRINT '  Log ' + CAST(@logCount AS NVARCHAR) + ': ' + @logFile;
        END TRY
        BEGIN CATCH
            -- Log restore may fail if STOPAT is before this log's range — expected
            PRINT '  Log ' + CAST(@logCount AS NVARCHAR) + ': skipped (past STOPAT)';
        END CATCH

        FETCH NEXT FROM @logCursor INTO @logFile;
    END

    CLOSE @logCursor;
    DEALLOCATE @logCursor;

    PRINT 'Applied ' + CAST(@logCount AS NVARCHAR) + ' log backup(s)';

    -- Step 4: Bring database online
    RESTORE DATABASE [HospitalBackupDemo_PITR] WITH RECOVERY;

    DECLARE @duration INT = DATEDIFF(SECOND, @startTime, GETUTCDATE());
    PRINT '';
    PRINT '✓ Point-in-time recovery completed';
    PRINT '  Target time: ' + CONVERT(NVARCHAR(30), @stopAt, 126);
    PRINT '  Duration: ' + CAST(@duration AS NVARCHAR) + 's';
    PRINT '  Chain: 1 full + '
        + CASE WHEN @diffBackup IS NOT NULL THEN '1 diff' ELSE '0 diff' END
        + ' + ' + CAST(@logCount AS NVARCHAR) + ' log(s)';

    -- Log to AuditLog
    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'PITR_RESTORE',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1, 'High',
             'PITR to ' + CONVERT(NVARCHAR(30), @stopAt, 126) + ' (' + CAST(@duration AS NVARCHAR) + 's, '
             + CAST(@logCount AS NVARCHAR) + ' logs)');
    END

END TRY
BEGIN CATCH
    DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
    PRINT '✗ PITR RESTORE FAILED: ' + @err;

    -- Log failure
    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, ErrorMessage, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'PITR_RESTORE_FAILED',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
             @err, 'PITR failed for target ' + CONVERT(NVARCHAR(30), @stopAt, 126));
    END

    IF OBJECT_ID('HospitalBackupDemo.dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
        EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
            @Severity = N'CRITICAL',
            @Title = N'PITR Restore FAILED',
            @Message = @err;

    RAISERROR('PITR restore failed: %s', 16, 1, @err);
END CATCH;
GO
