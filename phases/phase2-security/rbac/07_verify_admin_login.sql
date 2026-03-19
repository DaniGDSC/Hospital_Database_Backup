-- Verify admin login replacement and SA disable
-- CIS SQL Server Benchmark 2.1 verification
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║           Admin Login Verification (CIS 2.1)                   ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @PassCount INT = 0;
DECLARE @FailCount INT = 0;

-- Test 1: hospital_dba_admin exists and is enabled
PRINT '--- Test 1: hospital_dba_admin login exists ---';
IF EXISTS (SELECT 1 FROM sys.server_principals
           WHERE name = 'hospital_dba_admin' AND type = 'S' AND is_disabled = 0)
BEGIN
    PRINT '  ✓ PASS: Login exists and is enabled';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: Login not found or disabled';
    SET @FailCount = @FailCount + 1;
END

-- Test 2: hospital_dba_admin has sysadmin
PRINT '';
PRINT '--- Test 2: hospital_dba_admin has sysadmin role ---';
IF IS_SRVROLEMEMBER('sysadmin', 'hospital_dba_admin') = 1
BEGIN
    PRINT '  ✓ PASS: sysadmin role confirmed';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: sysadmin role NOT granted';
    SET @FailCount = @FailCount + 1;
END

-- Test 3: SA is renamed (sid 0x01 should not be named 'sa')
PRINT '';
PRINT '--- Test 3: SA account renamed ---';
DECLARE @SaCurrentName NVARCHAR(128);
SELECT @SaCurrentName = name FROM sys.server_principals WHERE sid = 0x01;

IF @SaCurrentName <> 'sa'
BEGIN
    PRINT '  ✓ PASS: SA renamed to ' + @SaCurrentName;
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: SA still named ''sa''';
    SET @FailCount = @FailCount + 1;
END

-- Test 4: SA (renamed) is disabled
PRINT '';
PRINT '--- Test 4: SA account disabled ---';
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE sid = 0x01 AND is_disabled = 1)
BEGIN
    PRINT '  ✓ PASS: SA account is disabled';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: SA account is still ENABLED';
    SET @FailCount = @FailCount + 1;
END

-- Test 5: All SQL Agent jobs still have valid owner
PRINT '';
PRINT '--- Test 5: SQL Agent jobs have valid owner ---';
DECLARE @OrphanedJobs INT;
SELECT @OrphanedJobs = COUNT(*)
FROM msdb.dbo.sysjobs j
LEFT JOIN sys.server_principals p ON j.owner_sid = p.sid
WHERE p.sid IS NULL OR p.is_disabled = 1;

IF @OrphanedJobs = 0
BEGIN
    PRINT '  ✓ PASS: All jobs have valid, active owners';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ⚠ WARN: ' + CAST(@OrphanedJobs AS NVARCHAR) + ' job(s) may need owner update';
    PRINT '  Run: EXEC msdb.dbo.sp_update_job @job_name=''...'', @owner_login_name=''hospital_dba_admin''';
    SET @FailCount = @FailCount + 1;
END

-- Test 6: Password policy enforced on admin login
PRINT '';
PRINT '--- Test 6: Password policy enforced ---';
IF EXISTS (SELECT 1 FROM sys.sql_logins
           WHERE name = 'hospital_dba_admin' AND is_policy_checked = 1)
BEGIN
    PRINT '  ✓ PASS: CHECK_POLICY = ON';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: CHECK_POLICY is OFF';
    SET @FailCount = @FailCount + 1;
END

-- Summary
PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '  PASS: ' + CAST(@PassCount AS NVARCHAR(10));
PRINT '  FAIL: ' + CAST(@FailCount AS NVARCHAR(10));
PRINT '═══════════════════════════════════════════════════';

IF @FailCount > 0
    RAISERROR('Admin login verification: %d test(s) failed', 16, 1, @FailCount);
GO
