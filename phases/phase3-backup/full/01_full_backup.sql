-- Full backup for HospitalBackupDemo
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Starting FULL backup for HospitalBackupDemo ===';

DECLARE @backupDir NVARCHAR(260) = N'/var/opt/mssql/backup/full';
DECLARE @fileName NVARCHAR(400) = @backupDir + N'/HospitalBackupDemo_FULL_' +
    CONVERT(CHAR(8), GETDATE(), 112) + '_' + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '') + N'.bak';
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'BACKUP DATABASE HospitalBackupDemo
    TO DISK = ''' + @fileName + N'''
    WITH INIT, FORMAT, COMPRESSION, CHECKSUM,
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''Full backup of HospitalBackupDemo (Encrypted AES_256)'';';

EXEC (@sql);
PRINT '✓ Full backup completed: ' + @fileName;
GO
