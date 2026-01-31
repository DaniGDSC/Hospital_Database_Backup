-- Purge encryption artifacts for HospitalBackupDemo (TDE + column-level)
-- WARNING: This will disable TDE and remove column encryption keys/certs.
-- Ensure you have backups and understand the impact before running.

SET NOCOUNT ON;

PRINT '=== Purge: Disabling TDE for HospitalBackupDemo ===';
USE master;
GO

-- Turn off TDE if currently enabled
IF EXISTS (
    SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('HospitalBackupDemo')
)
BEGIN
    ALTER DATABASE HospitalBackupDemo SET ENCRYPTION OFF;
    PRINT 'TDE OFF initiated. Waiting for decryption to complete...';
END
ELSE
BEGIN
    PRINT 'TDE not enabled or DEK not present.';
END
GO

-- Wait until decryption completes (state 1 = unencrypted, or no row)
DECLARE @state INT;
DECLARE @tries INT = 0;
WHILE 1 = 1
BEGIN
    SELECT @state = encryption_state
    FROM sys.dm_database_encryption_keys
    WHERE database_id = DB_ID('HospitalBackupDemo');

    IF @state IS NULL OR @state IN (0,1)
    BEGIN
        PRINT 'Decryption completed or no DEK present.';
        BREAK;
    END

    SET @tries += 1;
    IF @tries % 12 = 0 PRINT 'Still decrypting...';
    WAITFOR DELAY '00:00:05';
END
GO

-- Drop Database Encryption Key (DEK) if present
IF EXISTS (
    SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('HospitalBackupDemo')
)
BEGIN
    USE HospitalBackupDemo;
    DROP DATABASE ENCRYPTION KEY;
    PRINT 'Dropped Database Encryption Key.';
END
ELSE
BEGIN
    PRINT 'No DEK to drop.';
END
GO

-- Column-level encryption purge
USE HospitalBackupDemo;
GO
PRINT '=== Purge: Column-level encryption artifacts ===';

-- Null out encrypted values if column exists
IF COL_LENGTH('dbo.Patients', 'EncryptedNationalID') IS NOT NULL
BEGIN
    UPDATE dbo.Patients SET EncryptedNationalID = NULL;
    PRINT 'Cleared EncryptedNationalID values.';
END
ELSE
BEGIN
    PRINT 'EncryptedNationalID column not found; skipping clear.';
END
GO

-- Drop symmetric key if exists
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'HospitalBackupDemo_SymKey')
BEGIN
    -- Try to close if open, then drop
    BEGIN TRY
        CLOSE SYMMETRIC KEY HospitalBackupDemo_SymKey;
    END TRY BEGIN CATCH END;
    DROP SYMMETRIC KEY HospitalBackupDemo_SymKey;
    PRINT 'Dropped symmetric key HospitalBackupDemo_SymKey.';
END
ELSE
BEGIN
    PRINT 'Symmetric key HospitalBackupDemo_SymKey not found.';
END
GO

-- Drop column encryption certificate if exists
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_ColumnEncCert')
BEGIN
    DROP CERTIFICATE HospitalBackupDemo_ColumnEncCert;
    PRINT 'Dropped column encryption certificate HospitalBackupDemo_ColumnEncCert.';
END
ELSE
BEGIN
    PRINT 'Column encryption certificate not found.';
END
GO

-- Optionally drop the encrypted column
IF COL_LENGTH('dbo.Patients', 'EncryptedNationalID') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Patients DROP COLUMN EncryptedNationalID;
    PRINT 'Dropped EncryptedNationalID column.';
END
GO

-- Drop TDE certificate in master if exists
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
BEGIN
    DROP CERTIFICATE HospitalBackupDemo_TDECert;
    PRINT 'Dropped TDE certificate HospitalBackupDemo_TDECert.';
END
ELSE
BEGIN
    PRINT 'TDE certificate not found in master.';
END
GO

PRINT '✓ Purge completed.';
GO
