-- Define application roles
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating roles ===';

CREATE ROLE app_readwrite AUTHORIZATION dbo;
CREATE ROLE app_readonly AUTHORIZATION dbo;
CREATE ROLE app_billing AUTHORIZATION dbo;
CREATE ROLE app_security_admin AUTHORIZATION dbo;
CREATE ROLE app_auditor AUTHORIZATION dbo;
GO

PRINT '✓ Roles created.';
GO
