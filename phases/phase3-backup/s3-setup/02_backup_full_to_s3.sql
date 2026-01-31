-- Full backup to S3 (skips if credential not present)
USE master;
GO

SET NOCOUNT ON;

PRINT '=== FULL backup to S3 for HospitalBackupDemo ===';

DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';
-- Injected by sqlcmd: $(S3_BUCKET_NAME)
DECLARE @bucket NVARCHAR(200) = N's3://' + N'$(S3_BUCKET_NAME)' + N'/backups';
DECLARE @fileName NVARCHAR(400) = @bucket + N'/HospitalBackupDemo_FULL_' +
    CONVERT(CHAR(8), GETDATE(), 112) + '_' + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '') + N'.bak';

IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    PRINT 'Skipping: credential ' + @credName + ' not found. Run 01_create_s3_credential.sql with valid keys.';
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
