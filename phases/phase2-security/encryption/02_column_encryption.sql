-- Sample column-level encryption using symmetric key
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Configuring column encryption (demo) ===';

-- Ensure certificate exists
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_ColumnEncCert')
BEGIN
    RAISERROR('Certificate HospitalBackupDemo_ColumnEncCert not found. Run certificates scripts first.', 16, 1);
    RETURN;
END

-- Create symmetric key for data-at-rest encryption
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'HospitalBackupDemo_SymKey')
BEGIN
    CREATE SYMMETRIC KEY HospitalBackupDemo_SymKey
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE HospitalBackupDemo_ColumnEncCert;
    PRINT 'Symmetric key HospitalBackupDemo_SymKey created.';
END
ELSE
    PRINT 'Symmetric key HospitalBackupDemo_SymKey already exists.';
GO

-- Add encrypted column if missing
IF COL_LENGTH('dbo.Patients', 'EncryptedNationalID') IS NULL
BEGIN
    ALTER TABLE dbo.Patients ADD EncryptedNationalID VARBINARY(256) NULL;
    PRINT 'EncryptedNationalID column added to Patients.';
END
ELSE
    PRINT 'EncryptedNationalID column already exists.';
GO

-- Encrypt existing NationalID values (demo)
SET QUOTED_IDENTIFIER ON;
OPEN SYMMETRIC KEY HospitalBackupDemo_SymKey DECRYPTION BY CERTIFICATE HospitalBackupDemo_ColumnEncCert;

UPDATE p
SET EncryptedNationalID = CASE
    WHEN p.NationalID IS NOT NULL THEN EncryptByKey(Key_GUID('HospitalBackupDemo_SymKey'), p.NationalID)
    ELSE NULL END
FROM dbo.Patients p;

CLOSE SYMMETRIC KEY HospitalBackupDemo_SymKey;
GO

PRINT '✓ Column encryption completed (demo).';
GO
