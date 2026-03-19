-- Create application logins and database users
-- Passwords sourced via sqlcmd variables — never hardcode credentials.
-- Run with:
--   sqlcmd -v APP_RW_PASSWORD="..." APP_RO_PASSWORD="..." \
--          APP_BILLING_PASSWORD="..." APP_AUDIT_PASSWORD="..."
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Creating SQL logins ===';

-- Validate all passwords were provided
DECLARE @RwPass  NVARCHAR(128) = '$(APP_RW_PASSWORD)';
DECLARE @RoPass  NVARCHAR(128) = '$(APP_RO_PASSWORD)';
DECLARE @BillPass NVARCHAR(128) = '$(APP_BILLING_PASSWORD)';
DECLARE @AuditPass NVARCHAR(128) = '$(APP_AUDIT_PASSWORD)';

IF @RwPass = '$(APP_RW_PASSWORD)' OR LEN(@RwPass) < 12
BEGIN
    RAISERROR('APP_RW_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END
IF @RoPass = '$(APP_RO_PASSWORD)' OR LEN(@RoPass) < 12
BEGIN
    RAISERROR('APP_RO_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END
IF @BillPass = '$(APP_BILLING_PASSWORD)' OR LEN(@BillPass) < 12
BEGIN
    RAISERROR('APP_BILLING_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END
IF @AuditPass = '$(APP_AUDIT_PASSWORD)' OR LEN(@AuditPass) < 12
BEGIN
    RAISERROR('APP_AUDIT_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END

-- Create logins (idempotent)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_rw_login')
    EXEC('CREATE LOGIN app_rw_login WITH PASSWORD = ''' + @RwPass + '''');
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_ro_login')
    EXEC('CREATE LOGIN app_ro_login WITH PASSWORD = ''' + @RoPass + '''');
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'billing_login')
    EXEC('CREATE LOGIN billing_login WITH PASSWORD = ''' + @BillPass + '''');
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'auditor_login')
    EXEC('CREATE LOGIN auditor_login WITH PASSWORD = ''' + @AuditPass + '''');
GO

PRINT '✓ Logins created';

USE HospitalBackupDemo;
GO

PRINT '=== Creating database users and mapping to logins ===';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_rw_user')
    CREATE USER app_rw_user FOR LOGIN app_rw_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_ro_user')
    CREATE USER app_ro_user FOR LOGIN app_ro_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'billing_user')
    CREATE USER billing_user FOR LOGIN billing_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'auditor_user')
    CREATE USER auditor_user FOR LOGIN auditor_login;
GO

-- Role membership (idempotent — ALTER ROLE ADD MEMBER is safe to repeat)
ALTER ROLE app_readwrite ADD MEMBER app_rw_user;
ALTER ROLE app_readonly ADD MEMBER app_ro_user;
ALTER ROLE app_billing ADD MEMBER billing_user;
ALTER ROLE app_auditor ADD MEMBER auditor_user;
GO

PRINT '✓ Users created and added to roles.';
GO
