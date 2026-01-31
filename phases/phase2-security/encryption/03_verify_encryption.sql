-- Verify TDE and column-level encryption state for HospitalBackupDemo
SET NOCOUNT ON;

PRINT '=== Verify: TDE status ===';
USE master;
GO
SELECT d.name AS DatabaseName,
       d.is_encrypted AS IsEncrypted,
       dek.encryption_state AS EncryptionState,
       dek.key_algorithm AS KeyAlgorithm,
       dek.key_length AS KeyLength
FROM sys.databases d
LEFT JOIN sys.dm_database_encryption_keys dek ON dek.database_id = d.database_id
WHERE d.name = 'HospitalBackupDemo';
GO

PRINT '=== Verify: Encrypted column population ===';
USE HospitalBackupDemo;
GO
SELECT COUNT(*) AS EncryptedNationalID_NonNull
FROM dbo.Patients
WHERE EncryptedNationalID IS NOT NULL;
GO
SELECT TOP 5 PatientID, NationalID,
       CASE WHEN EncryptedNationalID IS NOT NULL THEN 1 ELSE 0 END AS HasEncrypted
FROM dbo.Patients
ORDER BY PatientID;
GO

PRINT '✓ Verification script completed.';
GO
