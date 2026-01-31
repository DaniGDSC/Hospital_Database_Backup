-- Full backup to S3 (using actual bucket name)
USE master;
GO

SET NOCOUNT ON;

PRINT '=== FULL backup to S3 for HospitalBackupDemo ===';

DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';
DECLARE @bucket NVARCHAR(200) = N's3://hospital-backup-prod-lock/backups';
DECLARE @fileName NVARCHAR(400) = @bucket + N'/HospitalBackupDemo_FULL_' +
    CONVERT(CHAR(8), GETDATE(), 112) + '_' + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '') + N'.bak';

IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    RAISERROR('Credential %s not found. Create it before running.', 16, 1, @credName);
    RETURN;
END

DECLARE @sql NVARCHAR(MAX) = N'BACKUP DATABASE HospitalBackupDemo
    TO URL = ''' + @fileName + N'''
    WITH CREDENTIAL = ''' + @credName + N''',
         COMPRESSION, CHECKSUM,
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''Full backup to S3 (Encrypted AES_256)'';';

EXEC (@sql);
PRINT '✓ Full backup sent to S3: ' + @fileName;
GO
