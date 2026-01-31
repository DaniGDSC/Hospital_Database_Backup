-- Create certificates used for TDE and column encryption
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

PRINT '=== (Optional) Backup TDE certificate and private key ===';
-- Adjust backup path and password for your environment
-- BACKUP CERTIFICATE HospitalBackupDemo_TDECert
--   TO FILE = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.cer'
--   WITH PRIVATE KEY (
--       FILE = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.pvk',
--       ENCRYPTION BY PASSWORD = 'Str0ng#CertBackup!2025'
--   );
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
