-- Create dedicated DBA admin login and disable SA
-- CIS SQL Server Benchmark 2.1: SA account must be disabled or renamed
-- HIPAA: Named accounts = auditable; SA = anonymous = compliance failure
--
-- Run with:
--   sqlcmd -v DBA_ADMIN_PASSWORD="$DBA_ADMIN_PASSWORD" -i 06_create_admin_login.sql
--
-- ⚠️ MANUAL STEP: Test connection with hospital_dba_admin BEFORE disabling SA
-- ⚠️ REQUIRES SA: Must run as sysadmin to create logins and disable SA
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║     CIS 2.1: Create Admin Login & Disable SA                   ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Step 1: Validate DBA password was provided
-- ============================================
DECLARE @DbaPassword NVARCHAR(128) = '$(DBA_ADMIN_PASSWORD)';

IF @DbaPassword = '$(DBA_ADMIN_PASSWORD)' OR LEN(@DbaPassword) < 16
BEGIN
    RAISERROR('DBA_ADMIN_PASSWORD must be provided via sqlcmd -v and be at least 16 characters.', 16, 1);
    RETURN;
END

-- ============================================
-- Step 2: Create dedicated admin login
-- ============================================
PRINT '--- Step 1: Creating hospital_dba_admin login ---';

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'hospital_dba_admin')
BEGIN
    EXEC('CREATE LOGIN [hospital_dba_admin] WITH PASSWORD = N''' + @DbaPassword + ''',
          CHECK_POLICY = ON, CHECK_EXPIRATION = OFF');
    PRINT '  ✓ Login hospital_dba_admin created';
END
ELSE
    PRINT '  ✓ Login hospital_dba_admin already exists';

-- Grant sysadmin (needed for backup/restore/TDE operations)
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members rm
    JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'hospital_dba_admin'
)
BEGIN
    ALTER SERVER ROLE [sysadmin] ADD MEMBER [hospital_dba_admin];
    PRINT '  ✓ Granted sysadmin role';
END
ELSE
    PRINT '  ✓ sysadmin role already granted';

-- ============================================
-- Step 3: Verify new login before disabling SA
-- ============================================
PRINT '';
PRINT '--- Step 2: Verifying hospital_dba_admin ---';

DECLARE @CanConnect INT;
SELECT @CanConnect = COUNT(*)
FROM sys.server_principals
WHERE name = 'hospital_dba_admin'
  AND type = 'S'
  AND is_disabled = 0;

IF @CanConnect = 0
BEGIN
    RAISERROR('ABORT: hospital_dba_admin login is not active. Cannot disable SA.', 16, 1);
    RETURN;
END

DECLARE @HasSysadmin INT;
SELECT @HasSysadmin = IS_SRVROLEMEMBER('sysadmin', 'hospital_dba_admin');

IF @HasSysadmin <> 1
BEGIN
    RAISERROR('ABORT: hospital_dba_admin does not have sysadmin. Cannot disable SA.', 16, 1);
    RETURN;
END

PRINT '  ✓ hospital_dba_admin is active with sysadmin';

-- ============================================
-- Step 4: Rename and disable SA
-- ============================================
PRINT '';
PRINT '--- Step 3: Disabling SA account ---';

-- Rename SA if not already renamed
DECLARE @SaName NVARCHAR(128);
SELECT @SaName = name FROM sys.server_principals WHERE sid = 0x01;

IF @SaName = 'sa'
BEGIN
    ALTER LOGIN [sa] WITH NAME = [hospital_sa_disabled];
    PRINT '  ✓ SA renamed to hospital_sa_disabled';
END
ELSE
    PRINT '  ✓ SA already renamed to: ' + @SaName;

-- Disable the renamed SA account
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE sid = 0x01 AND is_disabled = 0)
BEGIN
    ALTER LOGIN [hospital_sa_disabled] DISABLE;
    PRINT '  ✓ hospital_sa_disabled account DISABLED';
END
ELSE
    PRINT '  ✓ SA account already disabled';

-- ============================================
-- Step 5: Log to SecurityAuditEvents
-- ============================================
PRINT '';
PRINT '--- Step 4: Logging security event ---';

IF DB_ID('HospitalBackupDemo') IS NOT NULL
BEGIN
    EXEC('
    USE HospitalBackupDemo;
    INSERT INTO dbo.SecurityAuditEvents
        (EventTime, EventType, LoginName, DatabaseUser, ObjectName,
         ObjectType, Action, Success, ClientHost, ApplicationName, Details)
    VALUES
        (SYSDATETIME(), ''CIS_HARDENING'', SUSER_SNAME(), USER_NAME(),
         ''sa'', ''LOGIN'', ''DISABLE'', 1, HOST_NAME(), APP_NAME(),
         ''CIS 2.1: SA account renamed to hospital_sa_disabled and disabled. Replaced by hospital_dba_admin.'');
    ');
    PRINT '  ✓ Security event logged';
END
ELSE
    PRINT '  ⚠ HospitalBackupDemo not yet created — logging skipped';

-- ============================================
-- Summary
-- ============================================
PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║  ⚠️  ACTION REQUIRED:                                          ║';
PRINT '║  Test connection with hospital_dba_admin IMMEDIATELY:          ║';
PRINT '║                                                                ║';
PRINT '║  sqlcmd -S 127.0.0.1,14333 -U hospital_dba_admin              ║';
PRINT '║         -P "$DBA_ADMIN_PASSWORD" -Q "SELECT @@VERSION"         ║';
PRINT '║                                                                ║';
PRINT '║  If this fails, re-enable SA:                                  ║';
PRINT '║    ALTER LOGIN [hospital_sa_disabled] ENABLE;                  ║';
PRINT '║    ALTER LOGIN [hospital_sa_disabled] WITH NAME = [sa];        ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
GO
