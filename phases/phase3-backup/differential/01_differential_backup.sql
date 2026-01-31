-- Differential backup for HospitalBackupDemo
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Starting DIFFERENTIAL backup for HospitalBackupDemo ===';

DECLARE @backupDir NVARCHAR(260) = N'/var/opt/mssql/backup/differential';
DECLARE @fileName NVARCHAR(400) = @backupDir + N'/HospitalBackupDemo_DIFF_' +
    CONVERT(CHAR(8), GETDATE(), 112) + '_' + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '') + N'.bak';
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'BACKUP DATABASE HospitalBackupDemo
    TO DISK = ''' + @fileName + N'''
    WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM,
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''Differential backup of HospitalBackupDemo (Encrypted AES_256)'';';

EXEC (@sql);
PRINT '✓ Differential backup completed: ' + @fileName;
GO
