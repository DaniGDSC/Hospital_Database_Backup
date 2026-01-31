-- Full restore to a recovery database for validation
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Starting full restore of HospitalBackupDemo to HospitalBackupDemo_Recovery ===';

DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_Recovery';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Recovery_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Recovery_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_Recovery_Log.ldf';
DECLARE @backupFile NVARCHAR(260);
DECLARE @sql NVARCHAR(MAX);

-- Find latest full backup for HospitalBackupDemo
SELECT TOP 1 @backupFile = bmf.physical_device_name
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

-- Drop target DB if exists
IF DB_ID(@targetDb) IS NOT NULL
BEGIN
    ALTER DATABASE @targetDb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE @targetDb;
    PRINT 'Dropped existing target database ' + @targetDb;
END

-- Restore with MOVE to alternate file paths
SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
    FROM DISK = N''' + @backupFile + N'''
    WITH MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
         MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
         MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
         REPLACE, RECOVERY, STATS = 10, CHECKSUM';

EXEC (@sql);
PRINT '✓ Full restore completed to ' + @targetDb;
GO
