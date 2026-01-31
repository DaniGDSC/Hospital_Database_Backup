-- Create master keys for encryption prerequisites
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Creating/validating master key in master ===';

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Daniel@2410';
    PRINT 'Master key created in master.';
END
ELSE
    PRINT 'Master key already exists in master.';
GO

USE HospitalBackupDemo;
GO

PRINT '=== Creating/validating database master key in HospitalBackupDemo ===';

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Daniel@2410';
    PRINT 'Database master key created in HospitalBackupDemo.';
END
ELSE
    PRINT 'Database master key already exists in HospitalBackupDemo.';
GO
