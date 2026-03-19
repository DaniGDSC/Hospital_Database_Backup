-- Verify session timeout enforcement is properly configured
-- HIPAA 45 CFR 164.312(a)(2)(iii)
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║           Session Timeout Verification                          ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @PassCount INT = 0;
DECLARE @FailCount INT = 0;

-- Test 1: Procedure exists
PRINT '--- Test 1: Procedure usp_EnforceSessionTimeout exists ---';
IF OBJECT_ID('dbo.usp_EnforceSessionTimeout', 'P') IS NOT NULL
BEGIN
    PRINT '  ✓ PASS: Procedure exists';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: Procedure not found';
    SET @FailCount = @FailCount + 1;
END

-- Test 2: SystemConfiguration has SessionTimeoutMinutes
PRINT '';
PRINT '--- Test 2: SessionTimeoutMinutes configured ---';
DECLARE @ConfigValue NVARCHAR(100);
SELECT @ConfigValue = ConfigValue
FROM dbo.SystemConfiguration
WHERE ConfigKey = 'SessionTimeoutMinutes' AND IsActive = 1;

IF @ConfigValue IS NOT NULL AND TRY_CAST(@ConfigValue AS INT) > 0
BEGIN
    PRINT '  ✓ PASS: SessionTimeoutMinutes = ' + @ConfigValue;
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: SessionTimeoutMinutes not configured or invalid';
    SET @FailCount = @FailCount + 1;
END

-- Test 3: SQL Agent job exists and is enabled
PRINT '';
PRINT '--- Test 3: SQL Agent job exists ---';
DECLARE @JobEnabled INT;
SELECT @JobEnabled = enabled
FROM msdb.dbo.sysjobs
WHERE name = N'HospitalBackup_Session_Timeout';

IF @JobEnabled = 1
BEGIN
    PRINT '  ✓ PASS: Job exists and is enabled';
    SET @PassCount = @PassCount + 1;
END
ELSE IF @JobEnabled IS NOT NULL
BEGIN
    PRINT '  ✗ FAIL: Job exists but is DISABLED';
    SET @FailCount = @FailCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: Job not found in msdb.dbo.sysjobs';
    SET @FailCount = @FailCount + 1;
END

-- Test 4: Job scheduled every 5 minutes
PRINT '';
PRINT '--- Test 4: Job schedule is every 5 minutes ---';
DECLARE @SubdayType INT, @SubdayInterval INT;
SELECT @SubdayType = ss.freq_subday_type, @SubdayInterval = ss.freq_subday_interval
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
JOIN msdb.dbo.sysschedules ss ON js.schedule_id = ss.schedule_id
WHERE j.name = N'HospitalBackup_Session_Timeout';

IF @SubdayType = 4 AND @SubdayInterval = 5
BEGIN
    PRINT '  ✓ PASS: Scheduled every 5 minutes';
    SET @PassCount = @PassCount + 1;
END
ELSE IF @SubdayType IS NOT NULL
BEGIN
    PRINT '  ✗ FAIL: Schedule is not every 5 minutes (type='
        + CAST(@SubdayType AS NVARCHAR) + ', interval='
        + CAST(@SubdayInterval AS NVARCHAR) + ')';
    SET @FailCount = @FailCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: No schedule attached to job';
    SET @FailCount = @FailCount + 1;
END

-- Test 5: Procedure runs without error
PRINT '';
PRINT '--- Test 5: Procedure executes successfully ---';
BEGIN TRY
    EXEC dbo.usp_EnforceSessionTimeout;
    PRINT '  ✓ PASS: Procedure executed without error';
    SET @PassCount = @PassCount + 1;
END TRY
BEGIN CATCH
    PRINT '  ✗ FAIL: Procedure error: ' + ERROR_MESSAGE();
    SET @FailCount = @FailCount + 1;
END CATCH

-- Summary
PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '  PASS: ' + CAST(@PassCount AS NVARCHAR(10));
PRINT '  FAIL: ' + CAST(@FailCount AS NVARCHAR(10));
PRINT '═══════════════════════════════════════════════════';

IF @FailCount > 0
    RAISERROR('Session timeout verification: %d test(s) failed', 16, 1, @FailCount);
GO
