-- Create development database with fake data only
-- HIPAA 45 CFR 164.514(b): PHI must NEVER be used in dev environments
--
-- This creates HospitalBackupDemo_Dev with identical schema to production
-- but populated with completely synthetic data
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         Development Database Setup (NO PHI)                     ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @DevDB NVARCHAR(128) = N'HospitalBackupDemo_Dev';

-- Create dev database if not exists
IF DB_ID(@DevDB) IS NULL
BEGIN
    EXEC('CREATE DATABASE [' + @DevDB + ']');
    PRINT '✓ Database ' + @DevDB + ' created';
END
ELSE
    PRINT '✓ Database ' + @DevDB + ' already exists';
GO

-- Mark as development environment in extended properties
USE HospitalBackupDemo_Dev;
GO

IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE name = 'Environment')
    EXEC sp_addextendedproperty @name = 'Environment', @value = 'development';
GO

IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE name = 'PHI_Status')
    EXEC sp_addextendedproperty @name = 'PHI_Status', @value = 'NO_PHI_ALLOWED';
GO

PRINT '✓ Development database marked as NO PHI environment';
PRINT '';
PRINT 'Next steps:';
PRINT '  1. Run schema creation scripts against HospitalBackupDemo_Dev';
PRINT '  2. Run: scripts/utilities/generate_fake_data.sh';
PRINT '  3. Load fake data into dev database';
GO
