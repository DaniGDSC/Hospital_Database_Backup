-- Transaction log backup for HospitalBackupDemo
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Starting LOG backup for HospitalBackupDemo ===';

DECLARE @backupDir NVARCHAR(260) = N'/var/opt/mssql/backup/log';
DECLARE @fileName NVARCHAR(400) = @backupDir + N'/HospitalBackupDemo_LOG_' +
    CONVERT(CHAR(8), GETDATE(), 112) + '_' + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '') + N'.trn';
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'BACKUP LOG HospitalBackupDemo
    TO DISK = ''' + @fileName + N'''
    WITH INIT, COMPRESSION, CHECKSUM,
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''Log backup of HospitalBackupDemo (Encrypted AES_256)'';';

EXEC (@sql);
PRINT '✓ Log backup completed: ' + @fileName;
GO
