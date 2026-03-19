-- Full CIS SQL Server Benchmark Assessment
-- Comprehensive security hardening check for HIPAA compliance
-- Categories: Authentication, Surface Area, Audit, Encryption
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         CIS SQL Server Benchmark — Full Assessment              ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @PassCount INT = 0;
DECLARE @FailCount INT = 0;
DECLARE @WarnCount INT = 0;

-- ============================================
-- Category 1: Authentication (CIS 2.1-2.3)
-- ============================================
PRINT '── Category 1: Authentication ──';
PRINT '';

-- 1.1 SA disabled or renamed
DECLARE @SaName NVARCHAR(128), @SaDisabled BIT;
SELECT @SaName = name, @SaDisabled = is_disabled
FROM sys.server_principals WHERE sid = 0x01;

IF @SaName <> 'sa' AND @SaDisabled = 1
BEGIN PRINT '  ✓ [1.1] SA renamed and disabled'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [1.1] SA NOT properly secured'; SET @FailCount += 1; END

-- 1.2 Named admin exists
IF EXISTS (SELECT 1 FROM sys.server_principals
           WHERE name = 'hospital_dba_admin' AND is_disabled = 0)
BEGIN PRINT '  ✓ [1.2] Named admin login exists'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [1.2] No named admin login'; SET @FailCount += 1; END

-- 1.3 Password policy enforced on all SQL logins
DECLARE @NoPolicyCount INT;
SELECT @NoPolicyCount = COUNT(*)
FROM sys.sql_logins
WHERE is_policy_checked = 0 AND name NOT LIKE '##%';

IF @NoPolicyCount = 0
BEGIN PRINT '  ✓ [1.3] Password policy enforced on all logins'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ⚠ [1.3] ' + CAST(@NoPolicyCount AS NVARCHAR) + ' login(s) without password policy'; SET @WarnCount += 1; END

-- 1.4 Login auditing
DECLARE @AuditLevel INT;
EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'AuditLevel', @AuditLevel OUTPUT;

IF @AuditLevel = 3
BEGIN PRINT '  ✓ [1.4] Login auditing: All (failed + successful)'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ⚠ [1.4] Login auditing level: ' + CAST(ISNULL(@AuditLevel, 0) AS NVARCHAR); SET @WarnCount += 1; END

-- ============================================
-- Category 2: Surface Area (CIS 2.4-2.8)
-- ============================================
PRINT '';
PRINT '── Category 2: Surface Area ──';
PRINT '';

DECLARE @ConfigVal INT;

-- 2.1 OLE Automation
SELECT @ConfigVal = CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures';
IF @ConfigVal = 0
BEGIN PRINT '  ✓ [2.1] OLE Automation: disabled'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [2.1] OLE Automation: ENABLED'; SET @FailCount += 1; END

-- 2.2 CLR
SELECT @ConfigVal = CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'clr enabled';
IF @ConfigVal = 0
BEGIN PRINT '  ✓ [2.2] CLR: disabled'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [2.2] CLR: ENABLED'; SET @FailCount += 1; END

-- 2.3 Ad Hoc Distributed Queries
SELECT @ConfigVal = CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ad Hoc Distributed Queries';
IF @ConfigVal = 0
BEGIN PRINT '  ✓ [2.3] Ad Hoc Distributed Queries: disabled'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [2.3] Ad Hoc Distributed Queries: ENABLED'; SET @FailCount += 1; END

-- 2.4 xp_cmdshell restricted (no proxy = sysadmin only)
DECLARE @ProxyCount INT;
SELECT @ProxyCount = COUNT(*) FROM sys.credentials WHERE name = '##xp_cmdshell_proxy_account##';
IF @ProxyCount = 0
BEGIN PRINT '  ✓ [2.4] xp_cmdshell: restricted to sysadmin'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ⚠ [2.4] xp_cmdshell: proxy account exists'; SET @WarnCount += 1; END

-- 2.5 Remote admin connections
SELECT @ConfigVal = CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote admin connections';
IF @ConfigVal = 0
BEGIN PRINT '  ✓ [2.5] Remote admin connections: disabled'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ⚠ [2.5] Remote admin connections: ENABLED'; SET @WarnCount += 1; END

-- ============================================
-- Category 3: Encryption (CIS 3.1-3.3)
-- ============================================
PRINT '';
PRINT '── Category 3: Encryption ──';
PRINT '';

-- 3.1 TDE enabled
DECLARE @TdeState INT;
SELECT @TdeState = encryption_state
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('HospitalBackupDemo');

IF @TdeState = 3
BEGIN PRINT '  ✓ [3.1] TDE: encrypted (state=3)'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [3.1] TDE: NOT encrypted (state=' + CAST(ISNULL(@TdeState, 0) AS NVARCHAR) + ')'; SET @FailCount += 1; END

-- 3.2 TDE certificate exists
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
BEGIN PRINT '  ✓ [3.2] TDE certificate exists'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [3.2] TDE certificate NOT found'; SET @FailCount += 1; END

-- 3.3 Database master key exists
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN PRINT '  ✓ [3.3] Database master key exists'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [3.3] Database master key NOT found'; SET @FailCount += 1; END

-- ============================================
-- Category 4: Audit Controls (CIS 4.1-4.3)
-- ============================================
PRINT '';
PRINT '── Category 4: Audit Controls ──';
PRINT '';

-- 4.1 Audit tables protected (DENY DELETE/UPDATE)
USE HospitalBackupDemo;

DECLARE @AuditProtected INT = 0;
IF EXISTS (SELECT 1 FROM sys.database_permissions
           WHERE class_desc = 'OBJECT_OR_COLUMN'
           AND type = 'DL' -- DELETE
           AND state = 'D' -- DENY
           AND OBJECT_NAME(major_id) = 'AuditLog')
    SET @AuditProtected = @AuditProtected + 1;

IF @AuditProtected > 0
BEGIN PRINT '  ✓ [4.1] Audit tables: DELETE denied'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [4.1] Audit tables: NOT protected'; SET @FailCount += 1; END

-- 4.2 PHI audit triggers exist
DECLARE @TriggerCount INT;
SELECT @TriggerCount = COUNT(*)
FROM sys.triggers
WHERE name IN ('trg_MedicalRecords_Audit', 'trg_Patients_Audit',
               'trg_Prescriptions_Audit', 'trg_LabTests_Audit',
               'trg_Appointments_Audit');

IF @TriggerCount = 5
BEGIN PRINT '  ✓ [4.2] PHI audit triggers: all 5 present'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [4.2] PHI audit triggers: only ' + CAST(@TriggerCount AS NVARCHAR) + '/5'; SET @FailCount += 1; END

-- 4.3 DDL trigger protects audit tables
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
BEGIN PRINT '  ✓ [4.3] DDL trigger: audit tables protected from DROP/ALTER'; SET @PassCount += 1; END
ELSE
BEGIN PRINT '  ✗ [4.3] DDL trigger: NOT protecting audit tables'; SET @FailCount += 1; END

-- ============================================
-- Final Score
-- ============================================
PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';

DECLARE @Total INT = @PassCount + @FailCount + @WarnCount;
DECLARE @Score INT = CASE WHEN @Total > 0 THEN (@PassCount * 100) / @Total ELSE 0 END;

PRINT '║  CIS Benchmark Score: ' + CAST(@PassCount AS NVARCHAR) + '/' + CAST(@Total AS NVARCHAR)
    + ' (' + CAST(@Score AS NVARCHAR) + '%)';
PRINT '║';
PRINT '║  ✓ PASS: ' + CAST(@PassCount AS NVARCHAR(10));
PRINT '║  ⚠ WARN: ' + CAST(@WarnCount AS NVARCHAR(10));
PRINT '║  ✗ FAIL: ' + CAST(@FailCount AS NVARCHAR(10));
PRINT '╚════════════════════════════════════════════════════════════════╝';

IF @FailCount > 0
    PRINT '  Action: Fix ' + CAST(@FailCount AS NVARCHAR) + ' FAIL item(s) before production';
GO
