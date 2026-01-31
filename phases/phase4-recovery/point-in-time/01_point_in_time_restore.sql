-- Point-in-time restore for HospitalBackupDemo
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Point-in-time restore to HospitalBackupDemo_PITR ===';

DECLARE @stopAt DATETIME2 = '2025-12-31T23:59:00'; -- set desired recovery time
DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_PITR';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_PITR_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_PITR_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_PITR_Log.ldf';
DECLARE @fullBackup NVARCHAR(260);
DECLARE @diffBackup NVARCHAR(260);
DECLARE @logCursor CURSOR;
DECLARE @logFile NVARCHAR(260);
DECLARE @sql NVARCHAR(MAX);

-- Latest full before stop time
SELECT TOP 1 @fullBackup = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'HospitalBackupDemo'
  AND bs.type = 'D'
  AND bs.backup_finish_date <= @stopAt
ORDER BY bs.backup_finish_date DESC;

IF @fullBackup IS NULL
BEGIN
    RAISERROR('No full backup found before stop time.', 16, 1);
    RETURN;
END

-- Latest differential before stop time (optional)
SELECT TOP 1 @diffBackup = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'HospitalBackupDemo'
  AND bs.type = 'I'
  AND bs.backup_finish_date <= @stopAt
ORDER BY bs.backup_finish_date DESC;

-- Drop target DB if exists
IF DB_ID(@targetDb) IS NOT NULL
BEGIN
    ALTER DATABASE @targetDb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE @targetDb;
END

-- Restore full WITH NORECOVERY
SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
    FROM DISK = N''' + @fullBackup + N'''
    WITH NORECOVERY,
         MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
         MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
         MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
         REPLACE, STATS = 5, CHECKSUM';
EXEC (@sql);
PRINT 'Full backup restored (NORECOVERY).';

-- Restore differential if present
IF @diffBackup IS NOT NULL
BEGIN
    SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
        FROM DISK = N''' + @diffBackup + N'''
        WITH NORECOVERY, STATS = 5, CHECKSUM';
    EXEC (@sql);
    PRINT 'Differential backup restored (NORECOVERY).';
END
ELSE
    PRINT 'No differential backup found before stop time; skipping.';

-- Cursor through log backups after last restored backup
SET @logCursor = CURSOR FAST_FORWARD FOR
    SELECT bmf.physical_device_name
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type = 'L'
      AND bs.backup_start_date >= (SELECT backup_finish_date FROM msdb.dbo.backupset WHERE physical_device_name = @fullBackup)
      AND bs.backup_finish_date <= @stopAt
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

-- Final recovery to the point in time
RESTORE DATABASE [HospitalBackupDemo_PITR] WITH RECOVERY, STOPAT = @stopAt;
PRINT '✓ Point-in-time recovery completed to ' + CONVERT(NVARCHAR(30), @stopAt, 126);
GO
