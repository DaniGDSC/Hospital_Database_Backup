-- Create master keys for encryption prerequisites
-- Password sourced via sqlcmd variable: sqlcmd -v MASTER_KEY_PASSWORD="..."
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Creating/validating master key in master ===';

DECLARE @MasterKeyPassword NVARCHAR(128) = '$(MASTER_KEY_PASSWORD)';

IF @MasterKeyPassword = '$(MASTER_KEY_PASSWORD)' OR LEN(@MasterKeyPassword) < 12
BEGIN
    RAISERROR('MASTER_KEY_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    EXEC('CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + @MasterKeyPassword + '''');
    PRINT 'Master key created in master.';
END
ELSE
    PRINT 'Master key already exists in master.';
GO

USE HospitalBackupDemo;
GO

PRINT '=== Creating/validating database master key in HospitalBackupDemo ===';

DECLARE @DbMasterKeyPassword NVARCHAR(128) = '$(MASTER_KEY_PASSWORD)';

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    EXEC('CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + @DbMasterKeyPassword + '''');
    PRINT 'Database master key created in HospitalBackupDemo.';
END
ELSE
    PRINT 'Database master key already exists in HospitalBackupDemo.';
GO
