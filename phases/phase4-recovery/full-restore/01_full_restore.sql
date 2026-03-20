-- Full restore to a recovery database for validation
-- Finds the latest full backup from msdb and restores to HospitalBackupDemo_Recovery
-- Used by: weekly DR drill, manual recovery testing
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Starting full restore to HospitalBackupDemo_Recovery ===';

DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_Recovery';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Recovery_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Recovery_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Recovery_Log.ldf';
DECLARE @backupFile NVARCHAR(260);
DECLARE @backupFinish DATETIME;
DECLARE @sql NVARCHAR(MAX);
DECLARE @startTime DATETIME = GETUTCDATE();

BEGIN TRY
    -- Find latest full backup
    SELECT TOP 1
        @backupFile = bmf.physical_device_name,
        @backupFinish = bs.backup_finish_date
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo' AND bs.type = 'D'
    ORDER BY bs.backup_finish_date DESC;

    IF @backupFile IS NULL
    BEGIN
        RAISERROR('No full backup found for HospitalBackupDemo.', 16, 1);
        RETURN;
    END

    PRINT 'Latest full backup: ' + @backupFile;
    PRINT 'Backup date: ' + CONVERT(NVARCHAR(30), @backupFinish, 126);

    -- Drop target DB if exists
    IF DB_ID(@targetDb) IS NOT NULL
    BEGIN
        ALTER DATABASE [HospitalBackupDemo_Recovery] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [HospitalBackupDemo_Recovery];
        PRINT 'Dropped existing ' + @targetDb;
    END

    -- Restore with MOVE to alternate file paths
    SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
        FROM DISK = N''' + @backupFile + N'''
        WITH MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
             MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
             MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
             REPLACE, RECOVERY, STATS = 10, CHECKSUM';
    EXEC (@sql);

    DECLARE @duration INT = DATEDIFF(SECOND, @startTime, GETUTCDATE());
    PRINT '✓ Full restore completed to ' + @targetDb + ' (' + CAST(@duration AS NVARCHAR) + 's)';

    -- Log success
    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'FULL_RESTORE',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1, 'High',
             'Full restore to ' + @targetDb + ' from ' + @backupFile + ' (' + CAST(@duration AS NVARCHAR) + 's)');
    END

END TRY
BEGIN CATCH
    DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
    PRINT '✗ FULL RESTORE FAILED: ' + @err;

    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, ErrorMessage, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'FULL_RESTORE_FAILED',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
             @err, 'Full restore failed from ' + ISNULL(@backupFile, 'NULL'));
    END

    IF OBJECT_ID('HospitalBackupDemo.dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
        EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
            @Severity = N'CRITICAL',
            @Title = N'Full Restore FAILED',
            @Message = @err;

    RAISERROR('Full restore failed: %s', 16, 1, @err);
END CATCH;
GO
