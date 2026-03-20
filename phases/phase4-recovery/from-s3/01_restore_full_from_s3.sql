-- Restore full backup from S3 URL to a separate recovery database
-- Dynamically finds the latest S3 full backup from msdb.dbo.backupset
-- Requires: S3 credential created by phase3-backup/s3-setup/01_create_s3_credential.sql
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Restoring HospitalBackupDemo from S3 to HospitalBackupDemo_FromS3 ===';

DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_FromS3';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_FromS3_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_FromS3_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_FromS3_Log.ldf';
DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';
DECLARE @backupUrl NVARCHAR(500);
DECLARE @backupFinish DATETIME;
DECLARE @sql NVARCHAR(MAX);
DECLARE @startTime DATETIME = GETUTCDATE();

BEGIN TRY
    -- Validate credential exists
    IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
    BEGIN
        RAISERROR('Credential %s not found. Run phase3-backup/s3-setup/01_create_s3_credential.sql first.', 16, 1, @credName);
        RETURN;
    END

    -- Find latest S3 full backup dynamically
    SELECT TOP 1
        @backupUrl = bmf.physical_device_name,
        @backupFinish = bs.backup_finish_date
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type = 'D'
      AND bmf.physical_device_name LIKE 's3://%'
    ORDER BY bs.backup_finish_date DESC;

    IF @backupUrl IS NULL
    BEGIN
        RAISERROR('No S3 full backup found in msdb.dbo.backupset for HospitalBackupDemo.', 16, 1);
        RETURN;
    END

    PRINT 'Latest S3 backup: ' + @backupUrl;
    PRINT 'Backup date: ' + CONVERT(NVARCHAR(30), @backupFinish, 126);

    -- Drop target DB if exists
    IF DB_ID(@targetDb) IS NOT NULL
    BEGIN
        ALTER DATABASE [HospitalBackupDemo_FromS3] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [HospitalBackupDemo_FromS3];
        PRINT 'Dropped existing ' + @targetDb;
    END

    -- Restore from S3
    SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
        FROM URL = N''' + @backupUrl + N'''
        WITH CREDENTIAL = ''' + @credName + N''',
             MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
             MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
             MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
             REPLACE, STATS = 10, CHECKSUM, RECOVERY';
    EXEC (@sql);

    DECLARE @duration INT = DATEDIFF(SECOND, @startTime, GETUTCDATE());
    PRINT '✓ Restore from S3 completed to ' + @targetDb + ' (' + CAST(@duration AS NVARCHAR) + 's)';

    -- Log success to AuditLog
    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'S3_RESTORE',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1, 'High',
             'S3 restore to ' + @targetDb + ' from ' + @backupUrl + ' (' + CAST(@duration AS NVARCHAR) + 's)');
    END

END TRY
BEGIN CATCH
    DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
    PRINT '✗ S3 RESTORE FAILED: ' + @err;

    -- Log failure
    IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO HospitalBackupDemo.dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, ErrorMessage, Notes)
        VALUES
            (SYSDATETIME(), 'RECOVERY', 'dbo', 0, 'INSERT', 'S3_RESTORE_FAILED',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
             @err, 'S3 restore failed for ' + ISNULL(@backupUrl, 'NULL'));
    END

    -- Telegram alert
    IF OBJECT_ID('HospitalBackupDemo.dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
        EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
            @Severity = N'CRITICAL',
            @Title = N'S3 Restore FAILED',
            @Message = @err;

    RAISERROR('S3 restore failed: %s', 16, 1, @err);
END CATCH;
GO
