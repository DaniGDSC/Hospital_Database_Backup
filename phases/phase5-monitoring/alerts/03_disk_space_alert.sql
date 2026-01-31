-- Disk Space Critical Alert
-- Monitors disk space on all drives and alerts on critical/warning thresholds
USE master;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║              DISK SPACE MONITORING & ALERT                    ║';
PRINT '║              All Drives - HospitalBackupDemo                  ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

CREATE TABLE #DiskInfo (
    Drive CHAR(1),
    FreeSpaceMB INT
);

-- Populate disk information
INSERT INTO #DiskInfo EXEC xp_fixeddrives;

DECLARE @criticalCount INT = 0;
DECLARE @warningCount INT = 0;
DECLARE @driveName CHAR(1);
DECLARE @freeSpaceMB INT;
DECLARE @criticalThreshold INT = 20;      -- 20 MB critical
DECLARE @warningThreshold INT = 100;      -- 100 MB warning
DECLARE @backupDriveFreeSpace INT;

PRINT '═══ DISK SPACE STATUS ═══';
PRINT '';

-- Get free space for backup drive (assume D: or /var/opt/mssql)
SELECT @backupDriveFreeSpace = FreeSpaceMB FROM #DiskInfo WHERE Drive = 'D';

DECLARE disk_cursor CURSOR FAST_FORWARD FOR
SELECT Drive, FreeSpaceMB FROM #DiskInfo ORDER BY Drive;

OPEN disk_cursor;
FETCH NEXT FROM disk_cursor INTO @driveName, @freeSpaceMB;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @status NVARCHAR(20);
    DECLARE @indicator NVARCHAR(5);
    
    IF @freeSpaceMB < @criticalThreshold
    BEGIN
        SET @status = 'CRITICAL';
        SET @indicator = '🔴';
        SET @criticalCount = @criticalCount + 1;
    END
    ELSE IF @freeSpaceMB < @warningThreshold
    BEGIN
        SET @status = 'WARNING';
        SET @indicator = '🟠';
        SET @warningCount = @warningCount + 1;
    END
    ELSE
    BEGIN
        SET @status = 'OK';
        SET @indicator = '✓';
    END
    
    PRINT @indicator + ' Drive ' + @driveName + ': ' + CAST(@freeSpaceMB AS NVARCHAR(10)) + ' MB free (' + @status + ')';
    
    FETCH NEXT FROM disk_cursor INTO @driveName, @freeSpaceMB;
END

CLOSE disk_cursor;
DEALLOCATE disk_cursor;

PRINT '';
PRINT '═══ BACKUP STORAGE ANALYSIS ═══';
PRINT '';

-- Check if backup drive has sufficient space for next backup
DECLARE @backupSizeEstimate INT = 50; -- Estimate 50 MB per full backup
IF @backupDriveFreeSpace IS NOT NULL
BEGIN
    IF @backupDriveFreeSpace < @backupSizeEstimate
    BEGIN
        PRINT '🔴 CRITICAL: Insufficient space for next backup';
        PRINT '   Available: ' + CAST(@backupDriveFreeSpace AS NVARCHAR(10)) + ' MB';
        PRINT '   Estimated needed: ' + CAST(@backupSizeEstimate AS NVARCHAR(10)) + ' MB';
        PRINT '   Action: Clean old backups or expand storage';
        SET @criticalCount = @criticalCount + 1;
    END
    ELSE
    BEGIN
        PRINT '✓ Backup drive has sufficient space';
        PRINT '  Available: ' + CAST(@backupDriveFreeSpace AS NVARCHAR(10)) + ' MB';
        PRINT '  Recommended reserve: 100 MB';
    END
END

PRINT '';
PRINT '═══ RECOMMENDATIONS ═══';
PRINT '';

IF @criticalCount > 0
BEGIN
    PRINT '🔴 CRITICAL ACTION REQUIRED';
    PRINT '  - Clean up old backup files (Phase 3 cleanup scripts)';
    PRINT '  - Compress backup files if possible';
    PRINT '  - Expand storage capacity immediately';
END
ELSE IF @warningCount > 0
BEGIN
    PRINT '🟠 MONITOR AND PLAN';
    PRINT '  - Schedule disk expansion soon';
    PRINT '  - Review backup retention policy';
    PRINT '  - Archive old backups to external storage';
END
ELSE
BEGIN
    PRINT '✓ NO ACTION REQUIRED';
    PRINT '  - Disk space is healthy';
    PRINT '  - Continue normal operations';
    PRINT '  - Maintain monthly disk capacity reviews';
END

PRINT '';
PRINT '═══ ALERT SUMMARY ═══';

IF @criticalCount > 0
BEGIN
    PRINT '🔴 ' + CAST(@criticalCount AS NVARCHAR) + ' CRITICAL, ' + CAST(@warningCount AS NVARCHAR) + ' WARNING';
    RAISERROR('Disk Space Alert: %d critical alert(s) detected', 16, 1, @criticalCount);
END
ELSE IF @warningCount > 0
BEGIN
    PRINT '🟠 0 CRITICAL, ' + CAST(@warningCount AS NVARCHAR) + ' WARNING';
END
ELSE
BEGIN
    PRINT '✓ All disk space checks passed';
END

PRINT '';
PRINT 'Timestamp: ' + CONVERT(NVARCHAR(30), GETDATE(), 126);
PRINT 'Thresholds: Critical < ' + CAST(@criticalThreshold AS NVARCHAR(5)) + ' MB, Warning < ' + CAST(@warningThreshold AS NVARCHAR(5)) + ' MB';

DROP TABLE #DiskInfo;
GO
