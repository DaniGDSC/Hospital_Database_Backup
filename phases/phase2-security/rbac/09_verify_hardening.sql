-- CIS SQL Server Benchmark Compliance Verification
-- Checks all hardening items applied by 06/07/08 scripts
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         CIS SQL Server Benchmark Verification                   ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @PassCount INT = 0;
DECLARE @FailCount INT = 0;

-- CIS 2.1: SA account disabled or renamed
PRINT '--- CIS 2.1: SA account ---';
DECLARE @SaName NVARCHAR(128), @SaDisabled BIT;
SELECT @SaName = name, @SaDisabled = is_disabled
FROM sys.server_principals WHERE sid = 0x01;

IF @SaName <> 'sa' AND @SaDisabled = 1
BEGIN
    PRINT '  ✓ PASS: SA renamed to ' + @SaName + ' and disabled';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: SA name=' + ISNULL(@SaName, 'NULL')
        + ', disabled=' + CAST(ISNULL(@SaDisabled, 0) AS NVARCHAR);
    SET @FailCount = @FailCount + 1;
END

-- CIS 2.2: OLE Automation disabled
PRINT '';
PRINT '--- CIS 2.2: OLE Automation ---';
DECLARE @OleValue INT;
SELECT @OleValue = CAST(value_in_use AS INT)
FROM sys.configurations WHERE name = 'Ole Automation Procedures';

IF @OleValue = 0
BEGIN
    PRINT '  ✓ PASS: OLE Automation disabled';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: OLE Automation is ENABLED';
    SET @FailCount = @FailCount + 1;
END

-- CIS 2.3: CLR disabled
PRINT '';
PRINT '--- CIS 2.3: CLR ---';
DECLARE @ClrValue INT;
SELECT @ClrValue = CAST(value_in_use AS INT)
FROM sys.configurations WHERE name = 'clr enabled';

IF @ClrValue = 0
BEGIN
    PRINT '  ✓ PASS: CLR disabled';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: CLR is ENABLED';
    SET @FailCount = @FailCount + 1;
END

-- CIS 2.4: Ad Hoc Distributed Queries disabled
PRINT '';
PRINT '--- CIS 2.4: Ad Hoc Distributed Queries ---';
DECLARE @AdhocValue INT;
SELECT @AdhocValue = CAST(value_in_use AS INT)
FROM sys.configurations WHERE name = 'Ad Hoc Distributed Queries';

IF @AdhocValue = 0
BEGIN
    PRINT '  ✓ PASS: Ad Hoc Distributed Queries disabled';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: Ad Hoc Distributed Queries ENABLED';
    SET @FailCount = @FailCount + 1;
END

-- CIS 2.6: xp_cmdshell restricted to sysadmin
PRINT '';
PRINT '--- CIS 2.6: xp_cmdshell access control ---';
-- On SQL Server, xp_cmdshell is restricted to sysadmin by default
-- Verify no proxy account allows non-sysadmin execution
DECLARE @ProxyExists INT;
SELECT @ProxyExists = COUNT(*)
FROM sys.credentials WHERE name = '##xp_cmdshell_proxy_account##';

IF @ProxyExists = 0
BEGIN
    PRINT '  ✓ PASS: xp_cmdshell restricted to sysadmin (no proxy)';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ⚠ WARN: xp_cmdshell proxy account exists — non-sysadmin can execute';
    SET @FailCount = @FailCount + 1;
END

-- CIS 2.11: Login auditing set to all
PRINT '';
PRINT '--- CIS 2.11: Login auditing ---';
DECLARE @AuditLevel INT;
EXEC xp_instance_regread
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'AuditLevel',
    @AuditLevel OUTPUT;

IF @AuditLevel = 3
BEGIN
    PRINT '  ✓ PASS: Login auditing = All (failed + successful)';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ⚠ WARN: Login auditing level = ' + CAST(ISNULL(@AuditLevel, -1) AS NVARCHAR)
        + ' (expected 3 = all)';
    SET @FailCount = @FailCount + 1;
END

-- Summary
PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '  CIS Score: ' + CAST(@PassCount AS NVARCHAR) + '/' + CAST(@PassCount + @FailCount AS NVARCHAR);
PRINT '  PASS: ' + CAST(@PassCount AS NVARCHAR);
PRINT '  FAIL: ' + CAST(@FailCount AS NVARCHAR);
PRINT '═══════════════════════════════════════════════════';

IF @FailCount > 0
    RAISERROR('CIS verification: %d item(s) failed', 16, 1, @FailCount);
GO
