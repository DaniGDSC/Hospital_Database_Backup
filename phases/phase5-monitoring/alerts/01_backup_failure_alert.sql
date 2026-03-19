-- Enhanced alert: detect failed backups, check backup age, RPO, and RTO violations
-- Creates shared procedure usp_GetBackupTimestamps used by all alert scripts
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

-- Create/update the shared backup timestamp procedure
IF OBJECT_ID('dbo.usp_GetBackupTimestamps', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetBackupTimestamps;
GO

CREATE PROCEDURE dbo.usp_GetBackupTimestamps
    @LastFull DATETIME OUTPUT,
    @LastDiff DATETIME OUTPUT,
    @LastLog  DATETIME OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @LastFull = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = 'HospitalBackupDemo' AND type = 'D';

    SELECT @LastDiff = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = 'HospitalBackupDemo' AND type = 'I';

    SELECT @LastLog = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = 'HospitalBackupDemo' AND type = 'L';
END
GO

PRINT '✓ Shared procedure usp_GetBackupTimestamps created';
GO

-- Run the backup failure alert checks
USE msdb;
GO

SET NOCOUNT ON;

PRINT '=== Enhanced Backup & Recovery Alerts for HospitalBackupDemo ===';
PRINT '';

-- Display recent backup history
SELECT TOP 20
    bs.database_name,
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.type AS BackupType,
    bs.backup_size,
    bs.compressed_backup_size,
    CASE WHEN bs.is_copy_only = 1 THEN 'CopyOnly' ELSE 'Normal' END AS CopyOnly,
    CASE WHEN bs.has_backup_checksums = 1 THEN 'Checksum' ELSE 'NoChecksum' END AS Checksum,
    COALESCE(bmf.physical_device_name, 'URL/NONE') AS Device,
    DATEDIFF(MINUTE, bs.backup_finish_date, GETDATE()) AS MinutesSinceBackup
FROM msdb.dbo.backupset bs
LEFT JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'HospitalBackupDemo'
ORDER BY bs.backup_finish_date DESC;

PRINT '';
PRINT '--- ALERT THRESHOLD CHECKS ---';
PRINT '';

DECLARE @lastFull DATETIME;
DECLARE @lastLog DATETIME;
DECLARE @lastDiff DATETIME;
DECLARE @alertMessage NVARCHAR(MAX) = '';
DECLARE @alertCount INT = 0;

EXEC HospitalBackupDemo.dbo.usp_GetBackupTimestamps
    @LastFull = @lastFull OUTPUT,
    @LastDiff = @lastDiff OUTPUT,
    @LastLog  = @lastLog OUTPUT;

-- Check 1: Full backup age (target: max 1 day, alert: > 2 days)
IF @lastFull IS NULL OR @lastFull < DATEADD(DAY, -2, GETDATE())
BEGIN
    SET @alertMessage = 'CRITICAL: Full backup is older than 2 days or missing (Last: ' + ISNULL(CONVERT(NVARCHAR(30), @lastFull, 126), 'NONE') + ')';
    PRINT '🔴 CRITICAL: ' + @alertMessage;
    SET @alertCount = @alertCount + 1;
END
ELSE IF @lastFull < DATEADD(HOUR, -24, GETDATE())
BEGIN
    SET @alertMessage = 'WARNING: Full backup is older than 24 hours (Last: ' + CONVERT(NVARCHAR(30), @lastFull, 126) + ')';
    PRINT '🟠 WARNING: ' + @alertMessage;
END
ELSE
BEGIN
    PRINT '✓ Full backup age OK (Last: ' + CONVERT(NVARCHAR(30), @lastFull, 126) + ')';
END

-- Check 2: RPO (Recovery Point Objective) - target 1 hour, alert if > 1 hour
IF @lastLog IS NULL OR @lastLog < DATEADD(HOUR, -1, GETDATE())
BEGIN
    SET @alertMessage = 'RPO VIOLATED: Last log backup > 1 hour old (Last: ' + ISNULL(CONVERT(NVARCHAR(30), @lastLog, 126), 'NONE') + ')';
    PRINT '🔴 CRITICAL: ' + @alertMessage;
    SET @alertCount = @alertCount + 1;
END
ELSE IF @lastLog < DATEADD(MINUTE, -45, GETDATE())
BEGIN
    PRINT '🟠 WARNING: Log backup approaching RPO (Last: ' + CONVERT(NVARCHAR(30), @lastLog, 126) + ')';
END
ELSE
BEGIN
    PRINT '✓ RPO OK - Log backup within 1 hour (Last: ' + CONVERT(NVARCHAR(30), @lastLog, 126) + ')';
END

-- Check 3: RTO (Recovery Time Objective) - differential backup presence
IF @lastDiff IS NULL OR @lastDiff < DATEADD(DAY, -1, GETDATE())
BEGIN
    PRINT '⚠ RTO: No recent differential backup (Last: ' + ISNULL(CONVERT(NVARCHAR(30), @lastDiff, 126), 'NONE') + ')';
    PRINT '  Note: Recovery will use full backup + all log files (slower RTO)';
END
ELSE
BEGIN
    PRINT '✓ RTO OK - Differential backup within 1 day (Last: ' + CONVERT(NVARCHAR(30), @lastDiff, 126) + ')';
END

-- Check 4: Backup checksum validation
IF EXISTS (SELECT 1 FROM msdb.dbo.backupset WHERE database_name = 'HospitalBackupDemo' AND has_backup_checksums = 0 AND backup_finish_date > DATEADD(DAY, -1, GETDATE()))
BEGIN
    PRINT '⚠ WARNING: Recent backup(s) without checksum validation';
END
ELSE
BEGIN
    PRINT '✓ Checksum validation: All recent backups verified';
END

PRINT '';

-- Final alert summary
IF @alertCount > 0
BEGIN
    RAISERROR('Backup Alert: %d critical issues detected', 16, 1, @alertCount);
END
ELSE
BEGIN
    PRINT 'Summary: All backup and recovery checks passed.';
END
GO
