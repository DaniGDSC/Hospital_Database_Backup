-- Create sample logins and database users
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Creating SQL logins (demo) ===';

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_rw_login')
    CREATE LOGIN app_rw_login WITH PASSWORD = 'Str0ng#Passw0rd!rw';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_ro_login')
    CREATE LOGIN app_ro_login WITH PASSWORD = 'Str0ng#Passw0rd!ro';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'billing_login')
    CREATE LOGIN billing_login WITH PASSWORD = 'Str0ng#Passw0rd!bill';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'auditor_login')
    CREATE LOGIN auditor_login WITH PASSWORD = 'Str0ng#Passw0rd!audit';
GO

USE HospitalBackupDemo;
GO

PRINT '=== Creating database users and mapping to logins ===';

CREATE USER app_rw_user FOR LOGIN app_rw_login;
CREATE USER app_ro_user FOR LOGIN app_ro_login;
CREATE USER billing_user FOR LOGIN billing_login;
CREATE USER auditor_user FOR LOGIN auditor_login;
GO

-- Role membership
ALTER ROLE app_readwrite ADD MEMBER app_rw_user;
ALTER ROLE app_readonly ADD MEMBER app_ro_user;
ALTER ROLE app_billing ADD MEMBER billing_user;
ALTER ROLE app_auditor ADD MEMBER auditor_user;
GO

PRINT '✓ Users created and added to roles.';
GO
