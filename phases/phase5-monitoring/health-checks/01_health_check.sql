-- Basic health checks for HospitalBackupDemo
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Health checks for HospitalBackupDemo ===';

-- Availability
SELECT name AS DatabaseName, state_desc AS State, recovery_model_desc AS RecoveryModel
FROM sys.databases WHERE name = 'HospitalBackupDemo';

-- Last backup times
SELECT
    bs.database_name,
    MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS LastFull,
    MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END) AS LastDiff,
    MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS LastLog
FROM msdb.dbo.backupset bs
WHERE bs.database_name = 'HospitalBackupDemo'
GROUP BY bs.database_name;

-- Disk space (drives) with critical threshold check
PRINT '--- Disk Space Usage ---';
DECLARE @diskAlert NVARCHAR(MAX);
DECLARE @criticalDisks INT = 0;

CREATE TABLE #DiskSpace (
    Drive CHAR(1),
    FreeSpaceMB INT
);
INSERT INTO #DiskSpace EXEC xp_fixeddrives;
SELECT Drive, FreeSpaceMB, 
       CASE WHEN FreeSpaceMB < 20 THEN '🔴 CRITICAL' 
            WHEN FreeSpaceMB < 100 THEN '🟠 WARNING'
            ELSE '✓ OK'
       END AS Status
FROM #DiskSpace;

SELECT @criticalDisks = COUNT(*) FROM #DiskSpace WHERE FreeSpaceMB < 20;
IF @criticalDisks > 0
    RAISERROR('ALERT: %d drive(s) with critical disk space (< 20 MB free)', 16, 1, @criticalDisks);

DROP TABLE #DiskSpace;

-- Top waits (short snapshot)
PRINT '';
PRINT '--- Wait Statistics (Top 10) ---';
SELECT TOP 10 wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
FROM sys.dm_os_wait_stats
ORDER BY wait_time_ms DESC;

-- Failed logins in last 24h (from SecurityEvents table)
PRINT '';
PRINT '--- Security Monitoring ---';
USE HospitalBackupDemo;
DECLARE @failedLogins INT = 0;
IF OBJECT_ID('dbo.SecurityEvents', 'U') IS NOT NULL
BEGIN
    SELECT @failedLogins = COUNT(*) FROM dbo.SecurityEvents 
    WHERE EventType = 'Login Failed' AND EventDate >= DATEADD(DAY, -1, GETDATE());
    
    IF @failedLogins > 5
        PRINT '🟠 WARNING: ' + CAST(@failedLogins AS NVARCHAR(10)) + ' failed logins in last 24 hours'
    ELSE
        PRINT '✓ Security: ' + CAST(@failedLogins AS NVARCHAR(10)) + ' failed logins in last 24 hours (OK)';
END
ELSE
    PRINT '⚠ SecurityEvents table not found; enable SQL Server auditing to track login failures';

USE master;
PRINT '';
PRINT '✓ Health checks completed at ' + CONVERT(NVARCHAR(30), GETDATE(), 126);
PRINT 'Note: Configure SQL Agent job to run this hourly for continuous monitoring';
GO
