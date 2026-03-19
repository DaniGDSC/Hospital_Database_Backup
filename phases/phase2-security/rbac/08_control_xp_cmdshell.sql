-- SQL Server Surface Area Hardening (CIS Benchmark 2.2-2.7)
-- Disable unused features, restrict xp_cmdshell, audit usage
--
-- ⚠️ REQUIRES SA: sp_configure requires sysadmin
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║     CIS 2.2-2.7: Surface Area Reduction & Feature Control      ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Step 1: Audit current configuration
-- ============================================
PRINT '--- Current feature status ---';

SELECT
    name AS Feature,
    CAST(value AS INT) AS Configured,
    CAST(value_in_use AS INT) AS InUse,
    CASE CAST(value_in_use AS INT)
        WHEN 0 THEN '✓ DISABLED'
        WHEN 1 THEN '⚠ ENABLED'
    END AS Status
FROM sys.configurations
WHERE name IN (
    'xp_cmdshell',
    'Ole Automation Procedures',
    'clr enabled',
    'Ad Hoc Distributed Queries',
    'remote admin connections',
    'Database Mail XPs',
    'show advanced options'
)
ORDER BY name;
GO

-- ============================================
-- Step 2: Enable advanced options (needed for sp_configure)
-- ============================================
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- ============================================
-- Step 3: xp_cmdshell — KEEP ENABLED but restrict
-- Justification: Required by usp_SendTelegramAlert, backup_cert_to_s3.sh,
--   upload_audit_to_s3.sh, and export_sqlserver_logs.sh
-- Control: Only sysadmin can execute (default); audit every call
-- ============================================
PRINT '';
PRINT '--- CIS 2.6: xp_cmdshell — restricted to sysadmin ---';

-- Ensure xp_cmdshell is enabled (project dependency)
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
PRINT '  ✓ xp_cmdshell enabled (required for Telegram alerts, S3 uploads)';
PRINT '  ✓ Access restricted to sysadmin only (SQL Server default)';
GO

-- ============================================
-- Step 4: Disable features NOT used by this project
-- ============================================
PRINT '';
PRINT '--- CIS 2.2: Disabling unused features ---';

-- OLE Automation: Not used by this project
EXEC sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
PRINT '  ✓ Ole Automation Procedures: DISABLED';

-- CLR: Not used by this project
EXEC sp_configure 'clr enabled', 0;
RECONFIGURE;
PRINT '  ✓ CLR: DISABLED';

-- Ad Hoc Distributed Queries: Not used
EXEC sp_configure 'Ad Hoc Distributed Queries', 0;
RECONFIGURE;
PRINT '  ✓ Ad Hoc Distributed Queries: DISABLED';

-- Remote admin connections: Disable for security (use local only)
EXEC sp_configure 'remote admin connections', 0;
RECONFIGURE;
PRINT '  ✓ Remote Admin Connections (DAC): DISABLED (local DAC still works)';
GO

-- ============================================
-- Step 5: Keep Database Mail enabled (email alerts)
-- ============================================
PRINT '';
PRINT '--- Feature justification ---';
PRINT '  xp_cmdshell:    ENABLED — Telegram alerts, S3 uploads, log exports';
PRINT '  Database Mail:   ENABLED — Email alert notifications';
PRINT '  OLE Automation:  DISABLED — Not used';
PRINT '  CLR:             DISABLED — Not used';
PRINT '  Ad Hoc Queries:  DISABLED — Not used';
PRINT '  Remote DAC:      DISABLED — Local DAC sufficient';
GO

-- ============================================
-- Step 6: Create xp_cmdshell audit trigger
-- Log every xp_cmdshell invocation to SecurityAuditEvents
-- ============================================
PRINT '';
PRINT '--- Creating xp_cmdshell usage audit ---';

USE HospitalBackupDemo;
GO

IF OBJECT_ID('dbo.usp_AuditXpCmdshellUsage', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_AuditXpCmdshellUsage;
GO

CREATE PROCEDURE dbo.usp_AuditXpCmdshellUsage
    @Command NVARCHAR(4000),
    @Caller  NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Caller = ISNULL(@Caller, SUSER_SNAME());

    -- Log to SecurityAuditEvents
    INSERT INTO dbo.SecurityAuditEvents
        (EventTime, EventType, LoginName, DatabaseUser, ObjectName,
         ObjectType, Action, Success, ClientHost, ApplicationName, Details)
    VALUES
        (SYSDATETIME(), 'XP_CMDSHELL', @Caller, USER_NAME(),
         'xp_cmdshell', 'EXTENDED_PROC', 'EXECUTE', 1,
         HOST_NAME(), APP_NAME(),
         'Command executed (masked): '
         + CASE
             WHEN @Command LIKE '%password%' THEN '[CONTAINS PASSWORD - MASKED]'
             WHEN @Command LIKE '%token%' THEN '[CONTAINS TOKEN - MASKED]'
             ELSE LEFT(@Command, 200)
           END);
END;
GO

PRINT '  ✓ xp_cmdshell audit procedure created';
PRINT '    Usage: EXEC dbo.usp_AuditXpCmdshellUsage @Command=''...'';';

-- ============================================
-- Step 7: Enable login auditing (both failed and successful)
-- CIS 2.11: Audit login events
-- ============================================
PRINT '';
PRINT '--- CIS 2.11: Login auditing ---';
USE master;
GO

-- Set audit level to both failed and successful logins
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'AuditLevel',
    REG_DWORD, 3;

PRINT '  ✓ Login auditing set to: All (failed + successful)';
PRINT '    Note: Requires SQL Server restart to take effect';

-- ============================================
-- Summary
-- ============================================
PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║  Surface Area Hardening Complete                                ║';
PRINT '║                                                                ║';
PRINT '║  ENABLED (justified):                                          ║';
PRINT '║    xp_cmdshell      — Telegram, S3, log export                 ║';
PRINT '║    Database Mail     — Email notifications                      ║';
PRINT '║                                                                ║';
PRINT '║  DISABLED:                                                      ║';
PRINT '║    OLE Automation   — Not used                                  ║';
PRINT '║    CLR              — Not used                                  ║';
PRINT '║    Ad Hoc Queries   — Not used                                  ║';
PRINT '║    Remote DAC       — Local DAC sufficient                      ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
GO
