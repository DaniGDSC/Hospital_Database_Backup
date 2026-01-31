-- Grant permissions to roles
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Granting permissions to roles ===';

-- Read/write role
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO app_readwrite;

-- Read-only role
GRANT SELECT ON SCHEMA::dbo TO app_readonly;

-- Billing role
GRANT SELECT, INSERT, UPDATE ON dbo.Billing TO app_billing;
GRANT SELECT, INSERT, UPDATE ON dbo.BillingDetails TO app_billing;
GRANT SELECT, INSERT, UPDATE ON dbo.Payments TO app_billing;

-- Auditor role (read plus view definition)
GRANT SELECT ON SCHEMA::dbo TO app_auditor;
GRANT VIEW DEFINITION TO app_auditor;

-- Security admin role: manage users/roles in this DB
GRANT ALTER ANY USER TO app_security_admin;
GRANT ALTER ANY ROLE TO app_security_admin;
GRANT VIEW DEFINITION TO app_security_admin;
GO

PRINT '✓ Permissions granted.';
GO
