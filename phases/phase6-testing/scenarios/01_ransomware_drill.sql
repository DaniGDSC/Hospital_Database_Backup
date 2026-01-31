-- Scenario: ransomware drill using S3 restore
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Ransomware drill: restore from S3 to clean DB ===';

DECLARE @targetDb SYSNAME = N'HospitalBackupDemo_RansomwareDrill';
DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';
DECLARE @backupUrl NVARCHAR(500) = N's3://your-bucket/backups/HospitalBackupDemo_FULL_latest.bak'; -- update
DECLARE @sql NVARCHAR(MAX);

IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    RAISERROR('Credential %s not found. Cannot perform drill.', 16, 1, @credName);
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
         MOVE ''HospitalBackupDemo_Data'' TO ''/var/opt/mssql/data/HospitalBackupDemo_Ransom_Data.mdf'',
         MOVE ''HospitalBackupDemo_Data2'' TO ''/var/opt/mssql/data/HospitalBackupDemo_Ransom_Data2.ndf'',
         MOVE ''HospitalBackupDemo_Log'' TO ''/var/opt/mssql/data/HospitalBackupDemo_Ransom_Log.ldf'',
         REPLACE, STATS = 10, CHECKSUM, RECOVERY;';
EXEC (@sql);
PRINT '✓ Ransomware drill restore completed to ' + @targetDb;
GO
