-- Backup verification health check
-- Reports: last verification per type, success rate, duration trending
-- NIST SP 800-34: Backup testing must be documented and monitored
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

DECLARE @AlertCount INT = 0;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         Backup Verification Health Check                        ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Check 1: Last verification status per backup type
-- FULL: must be verified within 7 days
-- DIFF: must be verified within 24 hours
-- LOG:  must be verified within 2 hours
-- ============================================

PRINT '--- Check 1: Last Verification Per Backup Type ---';
PRINT '';

IF OBJECT_ID('dbo.BackupVerificationLog', 'U') IS NULL
BEGIN
    PRINT '✗ CRITICAL: BackupVerificationLog table does not exist';
    PRINT '  Run: phases/phase3-backup/verification/02_backup_verification_log.sql';
    RAISERROR('BackupVerificationLog table missing', 16, 1);
    RETURN;
END

DECLARE @TypeCheck TABLE (
    BackupType NVARCHAR(20),
    MaxAgeDays FLOAT,
    Label NVARCHAR(20)
);
INSERT INTO @TypeCheck VALUES ('FULL', 7.0, 'FULL'), ('DIFFERENTIAL', 1.0, 'DIFF'), ('LOG', 0.083, 'LOG'); -- 0.083 = 2 hours

DECLARE @BType NVARCHAR(20), @MaxAge FLOAT, @BLabel NVARCHAR(20);
DECLARE @LastVerified DATETIME, @LastStatus VARCHAR(10), @AgeDays FLOAT;

DECLARE type_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT BackupType, MaxAgeDays, Label FROM @TypeCheck;
OPEN type_cursor;
FETCH NEXT FROM type_cursor INTO @BType, @MaxAge, @BLabel;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT TOP 1 @LastVerified = VerificationStart, @LastStatus = Status
    FROM dbo.BackupVerificationLog
    WHERE BackupType = @BType
    ORDER BY VerificationStart DESC;

    IF @LastVerified IS NULL
    BEGIN
        PRINT '  ✗ ' + @BLabel + ': No verification records found';
        SET @AlertCount = @AlertCount + 1;
    END
    ELSE
    BEGIN
        SET @AgeDays = DATEDIFF(MINUTE, @LastVerified, GETUTCDATE()) / 1440.0;

        IF @LastStatus = 'FAIL'
        BEGIN
            PRINT '  ✗ ' + @BLabel + ': Last verification FAILED at '
                + CONVERT(NVARCHAR(30), @LastVerified, 120);
            SET @AlertCount = @AlertCount + 1;
        END
        ELSE IF @AgeDays > @MaxAge
        BEGIN
            PRINT '  ⚠ ' + @BLabel + ': Last verified '
                + CONVERT(NVARCHAR(30), @LastVerified, 120)
                + ' (' + CAST(CAST(@AgeDays AS DECIMAL(10,1)) AS NVARCHAR) + ' days ago, max '
                + CAST(CAST(@MaxAge AS DECIMAL(10,1)) AS NVARCHAR) + ')';
            SET @AlertCount = @AlertCount + 1;
        END
        ELSE
            PRINT '  ✓ ' + @BLabel + ': ' + @LastStatus + ' at '
                + CONVERT(NVARCHAR(30), @LastVerified, 120);
    END

    SET @LastVerified = NULL;
    SET @LastStatus = NULL;
    FETCH NEXT FROM type_cursor INTO @BType, @MaxAge, @BLabel;
END
CLOSE type_cursor;
DEALLOCATE type_cursor;

-- ============================================
-- Check 2: Verification success rate (last 30 days)
-- Any FAIL = critical alert
-- ============================================

PRINT '';
PRINT '--- Check 2: Verification Success Rate (30 days) ---';
PRINT '';

DECLARE @TotalVerifications INT, @FailedVerifications INT;

SELECT @TotalVerifications = COUNT(*),
       @FailedVerifications = SUM(CASE WHEN Status = 'FAIL' THEN 1 ELSE 0 END)
FROM dbo.BackupVerificationLog
WHERE VerificationStart >= DATEADD(DAY, -30, GETUTCDATE());

IF @TotalVerifications = 0
BEGIN
    PRINT '  ⚠ No verification records in last 30 days';
    SET @AlertCount = @AlertCount + 1;
END
ELSE
BEGIN
    DECLARE @SuccessRate DECIMAL(5,1) = ((@TotalVerifications - @FailedVerifications) * 100.0) / @TotalVerifications;

    PRINT '  Total verifications: ' + CAST(@TotalVerifications AS NVARCHAR);
    PRINT '  Failed:              ' + CAST(@FailedVerifications AS NVARCHAR);
    PRINT '  Success rate:        ' + CAST(@SuccessRate AS NVARCHAR) + '%';

    IF @FailedVerifications > 0
    BEGIN
        PRINT '  ✗ CRITICAL: ' + CAST(@FailedVerifications AS NVARCHAR) + ' verification failure(s) in last 30 days';
        SET @AlertCount = @AlertCount + 1;
    END
    ELSE
        PRINT '  ✓ 100% verification success rate';
END

-- ============================================
-- Check 3: Verification duration trending
-- Compare last 7 days avg to previous 30 days avg
-- Alert if >50% slower (potential storage degradation)
-- ============================================

PRINT '';
PRINT '--- Check 3: Verification Duration Trending ---';
PRINT '';

DECLARE @RecentAvg FLOAT, @BaselineAvg FLOAT;

SELECT @RecentAvg = AVG(CAST(DurationSeconds AS FLOAT))
FROM dbo.BackupVerificationLog
WHERE VerificationStart >= DATEADD(DAY, -7, GETUTCDATE()) AND Status = 'PASS';

SELECT @BaselineAvg = AVG(CAST(DurationSeconds AS FLOAT))
FROM dbo.BackupVerificationLog
WHERE VerificationStart >= DATEADD(DAY, -30, GETUTCDATE())
  AND VerificationStart < DATEADD(DAY, -7, GETUTCDATE()) AND Status = 'PASS';

IF @RecentAvg IS NOT NULL AND @BaselineAvg IS NOT NULL AND @BaselineAvg > 0
BEGIN
    DECLARE @ChangePercent DECIMAL(5,1) = ((@RecentAvg - @BaselineAvg) / @BaselineAvg) * 100;

    PRINT '  Baseline avg (8-30d): ' + CAST(CAST(@BaselineAvg AS DECIMAL(10,1)) AS NVARCHAR) + 's';
    PRINT '  Recent avg (0-7d):    ' + CAST(CAST(@RecentAvg AS DECIMAL(10,1)) AS NVARCHAR) + 's';
    PRINT '  Change:               ' + CAST(@ChangePercent AS NVARCHAR) + '%';

    IF @ChangePercent > 50
    BEGIN
        PRINT '  ⚠ WARNING: Verification >50% slower — check storage health';
        SET @AlertCount = @AlertCount + 1;
    END
    ELSE
        PRINT '  ✓ Duration within normal range';
END
ELSE
    PRINT '  (Insufficient data for trend analysis)';

-- ============================================
-- Summary
-- ============================================

PRINT '';
IF @AlertCount = 0
    PRINT '✓ All backup verification health checks PASSED';
ELSE
BEGIN
    PRINT '✗ ' + CAST(@AlertCount AS NVARCHAR) + ' verification health check(s) need attention';
    RAISERROR('Backup verification health: %d issue(s) detected', 16, 1, @AlertCount);
END
GO
