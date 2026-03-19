-- Full backup for HospitalBackupDemo
-- Also creates the shared usp_PerformBackup procedure used by all backup types
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

-- Create/update the shared backup procedure
IF OBJECT_ID('dbo.usp_PerformBackup', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_PerformBackup;
GO

CREATE PROCEDURE dbo.usp_PerformBackup
    @BackupType NVARCHAR(20)  -- 'FULL', 'DIFFERENTIAL', or 'LOG'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BackupDir NVARCHAR(260);
    DECLARE @FileName NVARCHAR(400);
    DECLARE @TypeLabel NVARCHAR(20);
    DECLARE @Extension NVARCHAR(4);
    DECLARE @SqlNVARCHAR(MAX);
    DECLARE @WithOptions NVARCHAR(MAX);

    -- Determine directory, label, and extension based on backup type
    IF @BackupType = 'FULL'
    BEGIN
        SET @BackupDir = N'/var/opt/mssql/backup/full';
        SET @TypeLabel = N'FULL';
        SET @Extension = N'.bak';
        SET @WithOptions = N'INIT, FORMAT, COMPRESSION, CHECKSUM';
    END
    ELSE IF @BackupType = 'DIFFERENTIAL'
    BEGIN
        SET @BackupDir = N'/var/opt/mssql/backup/differential';
        SET @TypeLabel = N'DIFF';
        SET @Extension = N'.bak';
        SET @WithOptions = N'DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM';
    END
    ELSE IF @BackupType = 'LOG'
    BEGIN
        SET @BackupDir = N'/var/opt/mssql/backup/log';
        SET @TypeLabel = N'LOG';
        SET @Extension = N'.trn';
        SET @WithOptions = N'INIT, COMPRESSION, CHECKSUM';
    END
    ELSE
    BEGIN
        RAISERROR('Invalid @BackupType. Use FULL, DIFFERENTIAL, or LOG.', 16, 1);
        RETURN;
    END

    -- Build filename with timestamp
    SET @FileName = @BackupDir + N'/HospitalBackupDemo_' + @TypeLabel + N'_' +
        CONVERT(CHAR(8), GETDATE(), 112) + N'_' +
        REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '') + @Extension;

    -- Build and execute backup command
    IF @BackupType = 'LOG'
        SET @Sql= N'BACKUP LOG HospitalBackupDemo';
    ELSE
        SET @Sql= N'BACKUP DATABASE HospitalBackupDemo';

    SET @Sql= @Sql+ N'
    TO DISK = ''' + @FileName + N'''
    WITH ' + @WithOptions + N',
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''' + @TypeLabel + N' backup of HospitalBackupDemo (Encrypted AES_256)'';';

    PRINT '=== Starting ' + @TypeLabel + ' backup for HospitalBackupDemo ===';
    EXEC (@Sql);
    PRINT '✓ ' + @TypeLabel + ' backup completed: ' + @FileName;
END
GO

PRINT '✓ Shared backup procedure usp_PerformBackup created';
GO

-- Execute full backup
USE master;
GO

EXEC HospitalBackupDemo.dbo.usp_PerformBackup @BackupType = 'FULL';
GO
