-- RPO/RTO Monitoring & Alerting
-- Monitors Recovery Point Objective (data freshness) and Recovery Time Objective (recovery speed)
USE msdb;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║           RPO/RTO MONITORING & VALIDATION ALERT               ║';
PRINT '║                    HospitalBackupDemo                         ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @lastFull DATETIME;
DECLARE @lastDiff DATETIME;
DECLARE @lastLog DATETIME;
DECLARE @rpoMinutes INT;
DECLARE @rtoEstimateMinutes INT;
DECLARE @alertCount INT = 0;
DECLARE @rtoTarget INT = 240;      -- 4 hours in minutes
DECLARE @rpoTarget INT = 60;       -- 1 hour in minutes
DECLARE @fullBackupTarget INT = 1; -- 1 day in days
DECLARE @diffBackupTarget INT = 1; -- 1 day in days

-- Retrieve last backup times
SELECT @lastFull = MAX(backup_finish_date) FROM backupset WHERE database_name = 'HospitalBackupDemo' AND type = 'D';
SELECT @lastDiff = MAX(backup_finish_date) FROM backupset WHERE database_name = 'HospitalBackupDemo' AND type = 'I';
SELECT @lastLog = MAX(backup_finish_date) FROM backupset WHERE database_name = 'HospitalBackupDemo' AND type = 'L';

-- Calculate RPO (time since last log backup)
SET @rpoMinutes = ISNULL(DATEDIFF(MINUTE, @lastLog, GETDATE()), 999999);

-- Calculate RTO estimate (recovery will need full + differential/logs)
-- If no differential, add time for all log backups
SET @rtoEstimateMinutes = CASE 
    WHEN @lastDiff IS NULL THEN 10 + (@rpoMinutes / 60) -- Full + logs
    ELSE 10 + DATEDIFF(MINUTE, @lastDiff, GETDATE()) / 60 -- Full + diff + logs
END;

PRINT '═══ RPO ANALYSIS (Recovery Point Objective) ═══';
PRINT 'Target: Data loss risk < ' + CAST(@rpoTarget AS NVARCHAR) + ' minutes';
PRINT '';

IF @rpoMinutes > @rpoTarget
BEGIN
    PRINT '🔴 CRITICAL: RPO VIOLATED';
    PRINT '   Current: ' + CAST(@rpoMinutes AS NVARCHAR) + ' minutes (vs target ' + CAST(@rpoTarget AS NVARCHAR) + ' min)';
    PRINT '   Last log backup: ' + ISNULL(CONVERT(NVARCHAR(30), @lastLog, 126), 'NONE');
    PRINT '   Action: Check Phase 3 backup log job (should run hourly)';
    SET @alertCount = @alertCount + 1;
END
ELSE IF @rpoMinutes > (@rpoTarget * 0.8) -- 80% of target
BEGIN
    PRINT '🟠 WARNING: RPO Approaching Threshold';
    PRINT '   Current: ' + CAST(@rpoMinutes AS NVARCHAR) + ' minutes (80% of ' + CAST(@rpoTarget AS NVARCHAR) + ' min target)';
    PRINT '   Last log backup: ' + CONVERT(NVARCHAR(30), @lastLog, 126);
END
ELSE
BEGIN
    PRINT '✓ RPO OK';
    PRINT '   Current: ' + CAST(@rpoMinutes AS NVARCHAR) + ' minutes (target ' + CAST(@rpoTarget AS NVARCHAR) + ' min)';
    PRINT '   Last log backup: ' + CONVERT(NVARCHAR(30), @lastLog, 126);
END

PRINT '';
PRINT '═══ RTO ANALYSIS (Recovery Time Objective) ═══';
PRINT 'Target: Maximum acceptable recovery time: ' + CAST(@rtoTarget AS NVARCHAR) + ' minutes';
PRINT '';

IF @rtoEstimateMinutes > @rtoTarget
BEGIN
    PRINT '🟠 WARNING: RTO Estimate Exceeds Target';
    PRINT '   Estimated RTO: ' + CAST(@rtoEstimateMinutes AS NVARCHAR) + ' minutes (vs target ' + CAST(@rtoTarget AS NVARCHAR) + ' min)';
    PRINT '   Action: Verify Phase 4 recovery procedures can meet target';
END
ELSE
BEGIN
    PRINT '✓ RTO Estimate OK';
    PRINT '   Estimated RTO: ' + CAST(@rtoEstimateMinutes AS NVARCHAR) + ' minutes (target ' + CAST(@rtoTarget AS NVARCHAR) + ' min)';
END

PRINT '';
PRINT '═══ BACKUP STATUS ═══';
PRINT '';

-- Full backup
PRINT 'Full Backup:';
IF @lastFull IS NULL
BEGIN
    PRINT '  🔴 CRITICAL: No full backup found';
    SET @alertCount = @alertCount + 1;
END
ELSE IF @lastFull < DATEADD(DAY, -@fullBackupTarget, GETDATE())
BEGIN
    PRINT '  🟠 WARNING: Full backup older than ' + CAST(@fullBackupTarget AS NVARCHAR) + ' day(s)';
    PRINT '    Last: ' + CONVERT(NVARCHAR(30), @lastFull, 126);
END
ELSE
BEGIN
    PRINT '  ✓ Full backup OK - Last: ' + CONVERT(NVARCHAR(30), @lastFull, 126);
END

PRINT '';
PRINT 'Differential Backup:';
IF @lastDiff IS NULL
BEGIN
    PRINT '  ⚠ No differential backup (recovery will replay all logs - slower RTO)';
    PRINT '    Recommend: Schedule daily differential backup';
END
ELSE IF @lastDiff < DATEADD(DAY, -@diffBackupTarget, GETDATE())
BEGIN
    PRINT '  🟠 WARNING: Differential backup older than ' + CAST(@diffBackupTarget AS NVARCHAR) + ' day(s)';
    PRINT '    Last: ' + CONVERT(NVARCHAR(30), @lastDiff, 126);
END
ELSE
BEGIN
    PRINT '  ✓ Differential backup OK - Last: ' + CONVERT(NVARCHAR(30), @lastDiff, 126);
END

PRINT '';
PRINT 'Log Backup:';
IF @lastLog IS NULL
BEGIN
    PRINT '  🔴 CRITICAL: No log backup found (RPO impossible)';
    SET @alertCount = @alertCount + 1;
END
ELSE IF @lastLog < DATEADD(HOUR, -1, GETDATE())
BEGIN
    PRINT '  🔴 CRITICAL: Log backup older than 1 hour (RPO violated)';
    PRINT '    Last: ' + CONVERT(NVARCHAR(30), @lastLog, 126);
    SET @alertCount = @alertCount + 1;
END
ELSE IF @lastLog < DATEADD(MINUTE, -45, GETDATE())
BEGIN
    PRINT '  🟠 WARNING: Log backup approaching 1 hour threshold';
    PRINT '    Last: ' + CONVERT(NVARCHAR(30), @lastLog, 126);
END
ELSE
BEGIN
    PRINT '  ✓ Log backup OK - Last: ' + CONVERT(NVARCHAR(30), @lastLog, 126);
END

PRINT '';
PRINT '═══ ALERT SUMMARY ═══';
IF @alertCount > 0
BEGIN
    PRINT '🔴 ' + CAST(@alertCount AS NVARCHAR) + ' CRITICAL ALERT(S) DETECTED';
    RAISERROR('RPO/RTO Alert: %d critical issues detected', 16, 1, @alertCount);
END
ELSE
BEGIN
    PRINT '✓ All RPO/RTO checks passed';
END

PRINT '';
PRINT 'Timestamp: ' + CONVERT(NVARCHAR(30), GETDATE(), 126);
GO
