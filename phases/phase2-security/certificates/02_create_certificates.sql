-- Create certificates used for TDE and column encryption
-- CRITICAL: This script also backs up the TDE certificate.
-- Without the backup, encrypted data is UNRECOVERABLE if the server is lost.
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Creating TDE certificate in master ===';

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
BEGIN
    CREATE CERTIFICATE HospitalBackupDemo_TDECert
        WITH SUBJECT = 'TDE Certificate for HospitalBackupDemo',
             EXPIRY_DATE = '2099-12-31';
    PRINT 'TDE certificate created.';
END
ELSE
    PRINT 'TDE certificate already exists.';
GO

-- Back up TDE certificate and private key
-- Password sourced via sqlcmd variable: sqlcmd -v CERT_BACKUP_PASSWORD="..."
PRINT '=== Backing up TDE certificate and private key ===';

DECLARE @CertFile NVARCHAR(260) = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.cer';
DECLARE @KeyFile  NVARCHAR(260) = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.pvk';
DECLARE @Password NVARCHAR(128) = '$(CERT_BACKUP_PASSWORD)';

-- Validate password was provided (not the literal placeholder)
IF @Password = '$(CERT_BACKUP_PASSWORD)' OR LEN(@Password) < 12
BEGIN
    RAISERROR('CERT_BACKUP_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END

BACKUP CERTIFICATE HospitalBackupDemo_TDECert
    TO FILE = @CertFile
    WITH PRIVATE KEY (
        FILE = @KeyFile,
        ENCRYPTION BY PASSWORD = @Password
    );

PRINT '✓ TDE certificate backed up to: ' + @CertFile;
PRINT '✓ Private key backed up to:     ' + @KeyFile;
GO

USE HospitalBackupDemo;
GO

PRINT '=== Creating column encryption certificate in HospitalBackupDemo ===';

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_ColumnEncCert')
BEGIN
    CREATE CERTIFICATE HospitalBackupDemo_ColumnEncCert
        WITH SUBJECT = 'Column Encryption Certificate for HospitalBackupDemo',
             EXPIRY_DATE = '2099-12-31';
    PRINT 'Column encryption certificate created.';
END
ELSE
    PRINT 'Column encryption certificate already exists.';
GO
