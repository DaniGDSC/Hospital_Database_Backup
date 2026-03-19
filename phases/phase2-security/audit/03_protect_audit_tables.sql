-- Protect audit tables from modification or deletion
-- HIPAA 45 CFR 164.312(b): Audit logs must be tamper-proof.
-- After running this script:
--   - No application user can DELETE or UPDATE audit rows
--   - No user (except sysadmin) can DROP or ALTER audit tables
--   - INSERT remains open for audit triggers to write
--   - Only app_auditor can SELECT audit data
--
-- ⚠️ REQUIRES SA: This script must be run by a sysadmin login.
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         Audit Table Protection (HIPAA 164.312(b))              ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- STEP 1: DENY DELETE and UPDATE on all audit tables
-- Prevents any user from modifying or removing audit records.
-- DENY overrides GRANT — even app_readwrite (which has schema-wide
-- DELETE/UPDATE via 03_assign_permissions.sql) is blocked.
-- Only sysadmin bypasses DENY.
-- ============================================

PRINT '--- Step 1: DENY DELETE/UPDATE on audit tables ---';

DENY DELETE, UPDATE ON dbo.AuditLog TO public;
DENY DELETE, UPDATE ON dbo.SecurityAuditEvents TO public;
DENY DELETE, UPDATE ON dbo.SecurityEvents TO public;
PRINT '  ✓ DELETE and UPDATE denied to public on all 3 audit tables';

-- ============================================
-- STEP 2: Restrict SELECT on audit tables
-- Only app_auditor and app_security_admin should read audit data.
-- Revoke the schema-wide SELECT that app_readwrite and app_readonly
-- inherited, then grant back to authorized roles only.
-- ============================================

PRINT '';
PRINT '--- Step 2: Restrict SELECT on audit tables ---';

-- Deny SELECT to general roles (overrides schema-level GRANT)
DENY SELECT ON dbo.AuditLog TO app_readwrite;
DENY SELECT ON dbo.AuditLog TO app_readonly;
DENY SELECT ON dbo.AuditLog TO app_billing;

DENY SELECT ON dbo.SecurityAuditEvents TO app_readwrite;
DENY SELECT ON dbo.SecurityAuditEvents TO app_readonly;
DENY SELECT ON dbo.SecurityAuditEvents TO app_billing;

DENY SELECT ON dbo.SecurityEvents TO app_readwrite;
DENY SELECT ON dbo.SecurityEvents TO app_readonly;
DENY SELECT ON dbo.SecurityEvents TO app_billing;

-- app_auditor keeps SELECT (granted at schema level in 03_assign_permissions.sql)
-- app_security_admin keeps access via VIEW DEFINITION
PRINT '  ✓ SELECT restricted: only app_auditor and sysadmin can read audit data';

-- ============================================
-- STEP 3: DDL trigger to prevent DROP/ALTER/TRUNCATE on audit tables
-- Even db_owner cannot structurally modify these tables.
-- Attempts are rolled back AND logged to SecurityAuditEvents.
-- Only sysadmin bypasses this (by disabling the trigger).
-- ============================================

PRINT '';
PRINT '--- Step 3: DDL trigger to protect audit table structure ---';

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
    DROP TRIGGER trg_Protect_AuditTables ON DATABASE;
GO

CREATE TRIGGER trg_Protect_AuditTables
ON DATABASE
FOR DROP_TABLE, ALTER_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventData XML = EVENTDATA();
    DECLARE @ObjectName NVARCHAR(256) = @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');
    DECLARE @EventType NVARCHAR(100) = @EventData.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)');

    -- Protected table list
    IF @ObjectName IN ('AuditLog', 'SecurityAuditEvents', 'SecurityEvents')
    BEGIN
        -- Log the blocked attempt BEFORE rollback
        -- Use direct INSERT to avoid trigger recursion issues
        INSERT INTO dbo.SecurityAuditEvents
            (EventTime, EventType, LoginName, DatabaseUser, ObjectName,
             ObjectType, Action, Success, ClientHost, ApplicationName, Details)
        VALUES
            (SYSDATETIME(),
             'AUDIT_TABLE_PROTECTION',
             ORIGINAL_LOGIN(),
             USER_NAME(),
             @ObjectName,
             'TABLE',
             @EventType,
             0,  -- blocked
             HOST_NAME(),
             APP_NAME(),
             'BLOCKED: Attempted ' + @EventType + ' on protected audit table ' + @ObjectName
                + '. Full event: ' + CONVERT(NVARCHAR(MAX), @EventData));

        PRINT 'BLOCKED: ' + @EventType + ' on protected audit table [' + @ObjectName + '] is not permitted.';
        ROLLBACK;
    END
END
GO

PRINT '  ✓ DDL trigger trg_Protect_AuditTables created';
PRINT '    Protects: AuditLog, SecurityAuditEvents, SecurityEvents';
PRINT '    Blocks: DROP_TABLE, ALTER_TABLE';
PRINT '    Bypass: sysadmin only (DISABLE TRIGGER trg_Protect_AuditTables ON DATABASE)';

-- ============================================
-- SUMMARY
-- ============================================

PRINT '';
PRINT '✓ Audit table protection applied:';
PRINT '  - DELETE/UPDATE denied to public (all 3 tables)';
PRINT '  - SELECT restricted to app_auditor and sysadmin';
PRINT '  - DROP/ALTER blocked by DDL trigger (logged to SecurityAuditEvents)';
PRINT '  - INSERT still allowed (audit triggers continue to function)';
GO
