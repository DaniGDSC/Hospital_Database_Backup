-- Enable Transparent Data Encryption for HospitalBackupDemo
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Enabling TDE ===';

-- Ensure certificate exists in master (created in certificates/02_create_certificates.sql)
IF NOT EXISTS (SELECT 1 FROM master.sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
BEGIN
    RAISERROR('TDE certificate HospitalBackupDemo_TDECert not found in master. Run certificates scripts first.', 16, 1);
    RETURN;
END

-- Create DEK if missing
IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('HospitalBackupDemo'))
BEGIN
    CREATE DATABASE ENCRYPTION KEY
        WITH ALGORITHM = AES_256
        ENCRYPTION BY SERVER CERTIFICATE HospitalBackupDemo_TDECert;
    PRINT 'Database encryption key created.';
END
ELSE
    PRINT 'Database encryption key already exists.';
GO

-- Turn on encryption
IF NOT EXISTS (
    SELECT 1 FROM sys.databases WHERE name = 'HospitalBackupDemo' AND is_encrypted = 1
)
BEGIN
    ALTER DATABASE HospitalBackupDemo SET ENCRYPTION ON;
    PRINT 'Encryption ON initiated.';
END
ELSE
    PRINT 'Encryption is already ON.';
GO

-- Verify status
SELECT name AS DatabaseName,
       is_encrypted,
       encryption_state,
       key_algorithm,
       key_length
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('HospitalBackupDemo');
GO
