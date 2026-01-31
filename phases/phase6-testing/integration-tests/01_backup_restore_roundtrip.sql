-- Integration test: backup and restore round-trip
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Backup/Restore round-trip test ===';

DECLARE @fullPath NVARCHAR(260) = N'/var/opt/mssql/backup/test/HospitalBackupDemo_RT.bak';
DECLARE @testDb SYSNAME = N'HospitalBackupDemo_RT';
DECLARE @sql NVARCHAR(MAX);

-- Take a copy-only full backup
SET @sql = N'BACKUP DATABASE HospitalBackupDemo
    TO DISK = ''' + @fullPath + N'''
    WITH COPY_ONLY, INIT, COMPRESSION, CHECKSUM, STATS = 5, DESCRIPTION = ''Round-trip test'';';
EXEC (@sql);
PRINT 'Backup complete: ' + @fullPath;

-- Drop/restore test database
IF DB_ID(@testDb) IS NOT NULL
BEGIN
    ALTER DATABASE @testDb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE @testDb;
END

SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@testDb) + N'
    FROM DISK = ''' + @fullPath + N'''
    WITH MOVE ''HospitalBackupDemo_Data'' TO ''/var/opt/mssql/data/HospitalBackupDemo_RT_Data.mdf'',
         MOVE ''HospitalBackupDemo_Data2'' TO ''/var/opt/mssql/data/HospitalBackupDemo_RT_Data2.ndf'',
         MOVE ''HospitalBackupDemo_Log'' TO ''/var/opt/mssql/data/HospitalBackupDemo_RT_Log.ldf'',
         REPLACE, STATS = 5, CHECKSUM;';
EXEC (@sql);
PRINT 'Restore complete to ' + @testDb;

-- Smoke validation
SET @sql = N'SELECT ''Patients'' AS TableName, COUNT(*) AS Rows FROM ' + QUOTENAME(@testDb) + N'.dbo.Patients';
EXEC (@sql);

PRINT '✓ Round-trip test finished.';
GO
