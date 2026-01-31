-- Reinstall encryption: recreate keys/certificates, enable TDE, configure column encryption
-- Run after 00_purge_encryption.sql

SET NOCOUNT ON;

PRINT '=== Reinstall: Master keys and certificates ===';

-- Ensure master keys and TDE certificate
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng#MasterKey!2025';
    PRINT 'Master key created in master.';
END
ELSE PRINT 'Master key exists in master.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
BEGIN
    CREATE CERTIFICATE HospitalBackupDemo_TDECert
        WITH SUBJECT = 'TDE Certificate for HospitalBackupDemo',
             EXPIRY_DATE = '2099-12-31';
    PRINT 'TDE certificate created.';
END
ELSE PRINT 'TDE certificate exists.';
GO

-- Ensure DB master key and column cert
USE HospitalBackupDemo;
GO
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng#DBMasterKey!2025';
    PRINT 'Database master key created.';
END
ELSE PRINT 'Database master key exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_ColumnEncCert')
BEGIN
    CREATE CERTIFICATE HospitalBackupDemo_ColumnEncCert
        WITH SUBJECT = 'Column Encryption Certificate for HospitalBackupDemo',
             EXPIRY_DATE = '2099-12-31';
    PRINT 'Column encryption certificate created.';
END
ELSE PRINT 'Column encryption certificate exists.';
GO

PRINT '=== Reinstall: Enable TDE ===';
USE HospitalBackupDemo;
GO
IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('HospitalBackupDemo'))
BEGIN
    CREATE DATABASE ENCRYPTION KEY
        WITH ALGORITHM = AES_256
        ENCRYPTION BY SERVER CERTIFICATE HospitalBackupDemo_TDECert;
    PRINT 'Database encryption key created.';
END
ELSE PRINT 'Database encryption key already exists.';
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.databases WHERE name = 'HospitalBackupDemo' AND is_encrypted = 1
)
BEGIN
    ALTER DATABASE HospitalBackupDemo SET ENCRYPTION ON;
    PRINT 'Encryption ON initiated.';
END
ELSE PRINT 'Encryption already ON.';
GO

PRINT '=== Reinstall: Column-level Encryption ===';
USE HospitalBackupDemo;
GO
IF COL_LENGTH('dbo.Patients', 'EncryptedNationalID') IS NULL
BEGIN
    ALTER TABLE dbo.Patients ADD EncryptedNationalID VARBINARY(256) NULL;
    PRINT 'EncryptedNationalID column added.';
END
ELSE PRINT 'EncryptedNationalID column exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'HospitalBackupDemo_SymKey')
BEGIN
    CREATE SYMMETRIC KEY HospitalBackupDemo_SymKey
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE HospitalBackupDemo_ColumnEncCert;
    PRINT 'Symmetric key created.';
END
ELSE PRINT 'Symmetric key exists.';
GO

OPEN SYMMETRIC KEY HospitalBackupDemo_SymKey DECRYPTION BY CERTIFICATE HospitalBackupDemo_ColumnEncCert;
UPDATE p
SET EncryptedNationalID = CASE
    WHEN p.NationalID IS NOT NULL THEN EncryptByKey(Key_GUID('HospitalBackupDemo_SymKey'), p.NationalID)
    ELSE NULL END
FROM dbo.Patients p;
CLOSE SYMMETRIC KEY HospitalBackupDemo_SymKey;
GO

PRINT '=== Verification ===';
USE master;
GO
SELECT name, is_encrypted FROM sys.databases WHERE name = 'HospitalBackupDemo';
GO
USE HospitalBackupDemo;
GO
SELECT TOP 5 PatientID, NationalID, EncryptedNationalID FROM dbo.Patients ORDER BY PatientID;
GO
PRINT '✓ Reinstall completed.';
GO
