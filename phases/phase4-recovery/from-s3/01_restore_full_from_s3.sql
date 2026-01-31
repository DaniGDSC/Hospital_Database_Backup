-- Restore full backup from S3 URL
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Restoring HospitalBackupDemo from S3 to HospitalBackupDemo_FromS3 ===';

DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_FromS3';
DECLARE @dataPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_FromS3_Data.mdf';
DECLARE @dataPath2 NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_FromS3_Data2.ndf';
DECLARE @logPath NVARCHAR(260) = N'/var/opt/mssql/data/HospitalBackupDemo_FromS3_Log.ldf';
DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';
DECLARE @backupUrl NVARCHAR(500) = N's3://your-bucket/backups/HospitalBackupDemo_FULL_latest.bak'; -- update to actual object
DECLARE @sql NVARCHAR(MAX);

IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    RAISERROR('Credential %s not found. Create it before running.', 16, 1, @credName);
    RETURN;
END

IF DB_ID(@targetDb) IS NOT NULL
BEGIN
    ALTER DATABASE @targetDb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE @targetDb;
END

SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@targetDb) + N'
    FROM URL = N''' + @backupUrl + N'''
    WITH CREDENTIAL = ''' + @credName + N''',
         MOVE ''HospitalBackupDemo_Data'' TO N''' + @dataPath + N''',
         MOVE ''HospitalBackupDemo_Data2'' TO N''' + @dataPath2 + N''',
         MOVE ''HospitalBackupDemo_Log'' TO N''' + @logPath + N''',
         REPLACE, STATS = 10, CHECKSUM, RECOVERY';

EXEC (@sql);
PRINT '✓ Restore from S3 completed to ' + @targetDb;
GO
