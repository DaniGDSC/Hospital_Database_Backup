-- Verify the most recent full backup for HospitalBackupDemo
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Verifying latest FULL backup ===';

DECLARE @backupFile NVARCHAR(260);

SELECT TOP 1 @backupFile = bmf.physical_device_name
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'HospitalBackupDemo'
  AND bs.type = 'D' -- Full
ORDER BY bs.backup_finish_date DESC;

IF @backupFile IS NULL
BEGIN
    PRINT 'No full backup found to verify.';
    RETURN;
END

DECLARE @sql NVARCHAR(MAX) = N'RESTORE VERIFYONLY FROM DISK = ''' + @backupFile + N'''';
PRINT 'Verifying: ' + @backupFile;
EXEC (@sql);
PRINT '✓ Verification completed.';
GO
