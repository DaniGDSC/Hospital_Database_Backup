-- Restore production DB using latest S3 full as base, then local differential + logs
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
DECLARE @sql NVARCHAR(MAX);

-- Ensure S3 credential exists
IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    RAISERROR('Credential %s not found. Create it before running.', 16, 1, @credName);
    RETURN;
END

-- Find latest FULL backup to S3 URL
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

PRINT 'Latest S3 full backup: ' + @fullUrl + ' (finish: ' + CONVERT(NVARCHAR(30), @fullFinish, 126) + ')';

-- Find latest DIFFERENTIAL backup after the full (if any)
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
    ALTER DATABASE @targetDb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE @targetDb;
    PRINT 'Dropped existing target database ' + @targetDb;
END

-- Restore FULL from S3 WITH NORECOVERY
SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
    FROM URL = N''' + @fullUrl + N'''
    WITH CREDENTIAL = ''' + @credName + N''',
         MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
         MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
         MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
         REPLACE, NORECOVERY, STATS = 10, CHECKSUM';
EXEC (@sql);
PRINT 'Full backup restored from S3 (NORECOVERY).';

-- Restore DIFFERENTIAL if present
IF @diffFile IS NOT NULL
BEGIN
    PRINT 'Applying differential: ' + @diffFile + ' (finish: ' + CONVERT(NVARCHAR(30), @diffFinish, 126) + ')';
    SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
        FROM DISK = N''' + @diffFile + N'''
        WITH NORECOVERY, STATS = 10, CHECKSUM';
    EXEC (@sql);
    PRINT 'Differential backup restored (NORECOVERY).';
END
ELSE
    PRINT 'No differential backup found after S3 full; proceeding with logs.';

-- Apply LOG backups after base (full or differential)
DECLARE @logCursor CURSOR;
DECLARE @logFile NVARCHAR(500);

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
    SET @sql = N'RESTORE LOG ' + QUOTENAME(@targetDb) + N'
        FROM DISK = N''' + @logFile + N'''
        WITH NORECOVERY, STATS = 5, CHECKSUM';
    EXEC (@sql);
    PRINT 'Restored log: ' + @logFile;
    FETCH NEXT FROM @logCursor INTO @logFile;
END

CLOSE @logCursor;
DEALLOCATE @logCursor;

-- Final recovery
RESTORE DATABASE [HospitalBackupDemo] WITH RECOVERY;
PRINT '✓ Recovery completed: HospitalBackupDemo online.';
GO
