-- Verify audit table protection is working correctly
-- Run AFTER 03_protect_audit_tables.sql
-- All tests use TRY/CATCH — no audit data is modified on success.
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

DECLARE @TestsPassed INT = 0;
DECLARE @TestsFailed INT = 0;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         Audit Protection Verification Tests                     ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Test 1: DELETE on AuditLog must be blocked
-- ============================================
PRINT '--- Test 1: DELETE on dbo.AuditLog ---';
BEGIN TRY
    DELETE TOP(0) FROM dbo.AuditLog;
    -- If we get here, DELETE was allowed (FAIL)
    PRINT '  FAIL: DELETE succeeded — protection not working';
    SET @TestsFailed = @TestsFailed + 1;
END TRY
BEGIN CATCH
    PRINT '  PASS: DELETE blocked — ' + ERROR_MESSAGE();
    SET @TestsPassed = @TestsPassed + 1;
END CATCH

-- ============================================
-- Test 2: UPDATE on SecurityAuditEvents must be blocked
-- ============================================
PRINT '';
PRINT '--- Test 2: UPDATE on dbo.SecurityAuditEvents ---';
BEGIN TRY
    UPDATE TOP(0) dbo.SecurityAuditEvents SET EventType = 'TAMPERED';
    PRINT '  FAIL: UPDATE succeeded — protection not working';
    SET @TestsFailed = @TestsFailed + 1;
END TRY
BEGIN CATCH
    PRINT '  PASS: UPDATE blocked — ' + ERROR_MESSAGE();
    SET @TestsPassed = @TestsPassed + 1;
END CATCH

-- ============================================
-- Test 3: DELETE on SecurityEvents must be blocked
-- ============================================
PRINT '';
PRINT '--- Test 3: DELETE on dbo.SecurityEvents ---';
BEGIN TRY
    DELETE TOP(0) FROM dbo.SecurityEvents;
    PRINT '  FAIL: DELETE succeeded — protection not working';
    SET @TestsFailed = @TestsFailed + 1;
END TRY
BEGIN CATCH
    PRINT '  PASS: DELETE blocked — ' + ERROR_MESSAGE();
    SET @TestsPassed = @TestsPassed + 1;
END CATCH

-- ============================================
-- Test 4: INSERT on AuditLog must still work
-- (Audit triggers depend on this)
-- ============================================
PRINT '';
PRINT '--- Test 4: INSERT on dbo.AuditLog (must succeed) ---';
BEGIN TRY
    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, RecordID, Action, UserName, IsSuccess, Severity, Notes)
    VALUES
        (SYSDATETIME(), 'VERIFICATION_TEST', 0, 'INSERT', SUSER_SNAME(), 1, 'Low',
         'Audit protection verification — this row confirms INSERT still works');
    PRINT '  PASS: INSERT succeeded — audit triggers will function correctly';
    SET @TestsPassed = @TestsPassed + 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: INSERT blocked — audit triggers will break! ' + ERROR_MESSAGE();
    SET @TestsFailed = @TestsFailed + 1;
END CATCH

-- ============================================
-- Test 5: DDL trigger — verify it exists and protects tables
-- ============================================
PRINT '';
PRINT '--- Test 5: DDL trigger trg_Protect_AuditTables exists ---';
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
BEGIN
    PRINT '  PASS: DDL trigger exists at DATABASE level';
    SET @TestsPassed = @TestsPassed + 1;
END
ELSE
BEGIN
    PRINT '  FAIL: DDL trigger trg_Protect_AuditTables not found';
    SET @TestsFailed = @TestsFailed + 1;
END

-- ============================================
-- Test 6: Verify DENY permissions are in place
-- ============================================
PRINT '';
PRINT '--- Test 6: DENY permissions on audit tables ---';

DECLARE @DenyCount INT;
SELECT @DenyCount = COUNT(*)
FROM sys.database_permissions dp
JOIN sys.objects o ON dp.major_id = o.object_id
WHERE o.name IN ('AuditLog', 'SecurityAuditEvents', 'SecurityEvents')
  AND dp.state_desc = 'DENY'
  AND dp.permission_name IN ('DELETE', 'UPDATE');

IF @DenyCount >= 6  -- 2 permissions (DELETE, UPDATE) x 3 tables = 6 minimum
BEGIN
    PRINT '  PASS: Found ' + CAST(@DenyCount AS NVARCHAR) + ' DENY entries on audit tables';
    SET @TestsPassed = @TestsPassed + 1;
END
ELSE
BEGIN
    PRINT '  FAIL: Expected at least 6 DENY entries, found ' + CAST(@DenyCount AS NVARCHAR);
    SET @TestsFailed = @TestsFailed + 1;
END

-- ============================================
-- Summary
-- ============================================
PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '  Passed: ' + CAST(@TestsPassed AS NVARCHAR);
PRINT '  Failed: ' + CAST(@TestsFailed AS NVARCHAR);
PRINT '═══════════════════════════════════════════════════';
PRINT '';

IF @TestsFailed = 0
    PRINT '✓ All audit protection checks PASSED';
ELSE
BEGIN
    PRINT '✗ ' + CAST(@TestsFailed AS NVARCHAR) + ' check(s) FAILED — audit tables are NOT fully protected';
    RAISERROR('Audit protection verification failed: %d tests failed', 16, 1, @TestsFailed);
END
GO
