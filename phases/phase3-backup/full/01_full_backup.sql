-- Full backup for HospitalBackupDemo
-- Also creates the shared usp_PerformBackup procedure used by all backup types
-- NIST SP 800-34: Every backup is verified with RESTORE VERIFYONLY immediately after creation
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
    DECLARE @BackupSql NVARCHAR(MAX);
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
        SET @BackupSql = N'BACKUP LOG HospitalBackupDemo';
    ELSE
        SET @BackupSql = N'BACKUP DATABASE HospitalBackupDemo';

    SET @BackupSql = @BackupSql + N'
    TO DISK = ''' + @FileName + N'''
    WITH ' + @WithOptions + N',
         ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert),
         STATS = 10,
         DESCRIPTION = ''' + @TypeLabel + N' backup of HospitalBackupDemo (Encrypted AES_256)'';';

    PRINT '=== Starting ' + @TypeLabel + ' backup for HospitalBackupDemo ===';
    EXEC (@BackupSql);
    PRINT '✓ ' + @TypeLabel + ' backup completed: ' + @FileName;

    -- ================================================================
    -- VERIFY BACKUP IMMEDIATELY (NIST SP 800-34 requirement)
    -- CHECKSUM during write validates write integrity.
    -- RESTORE VERIFYONLY after write validates read integrity.
    -- Both are required for a verified backup.
    -- ================================================================
    DECLARE @VerifySql NVARCHAR(MAX);
    DECLARE @VerifyStart DATETIME = GETUTCDATE();
    DECLARE @VerifyDuration INT;

    SET @VerifySql = N'RESTORE VERIFYONLY FROM DISK = N''' + @FileName + N''' WITH CHECKSUM';

    PRINT '--- Verifying backup with RESTORE VERIFYONLY ---';

    BEGIN TRY
        EXEC (@VerifySql);

        SET @VerifyDuration = DATEDIFF(SECOND, @VerifyStart, GETUTCDATE());

        -- Log to BackupVerificationLog if table exists
        IF OBJECT_ID('dbo.BackupVerificationLog', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.BackupVerificationLog
                (BackupType, FileName, VerificationStart, VerificationEnd,
                 DurationSeconds, Status, VerifiedBy)
            VALUES
                (@BackupType, @FileName, @VerifyStart, GETUTCDATE(),
                 @VerifyDuration, 'PASS', SUSER_SNAME());
        END

        PRINT '✓ VERIFIED (' + CAST(@VerifyDuration AS NVARCHAR) + 's): ' + @FileName;

        -- Warn if log backup verification is slow (should be < 60s)
        IF @BackupType = 'LOG' AND @VerifyDuration > 60
            PRINT '⚠ WARNING: Log backup verification took ' + CAST(@VerifyDuration AS NVARCHAR)
                + 's (threshold: 60s) — check storage performance';
    END TRY
    BEGIN CATCH
        DECLARE @VerifyError NVARCHAR(MAX) = ERROR_MESSAGE();
        SET @VerifyDuration = DATEDIFF(SECOND, @VerifyStart, GETUTCDATE());

        -- Log failure to BackupVerificationLog if table exists
        IF OBJECT_ID('dbo.BackupVerificationLog', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.BackupVerificationLog
                (BackupType, FileName, VerificationStart, VerificationEnd,
                 DurationSeconds, Status, ErrorMessage, VerifiedBy)
            VALUES
                (@BackupType, @FileName, @VerifyStart, GETUTCDATE(),
                 @VerifyDuration, 'FAIL', @VerifyError, SUSER_SNAME());
        END

        -- Log to AuditLog for security audit trail
        INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity,
             ErrorMessage, Notes)
        VALUES
            (SYSDATETIME(), 'BACKUP_VERIFICATION', 'dbo', 0, 'SELECT', 'BACKUP_VERIFY_FAILED',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
             @VerifyError,
             'BACKUP VERIFICATION FAILED: ' + @TypeLabel + ' backup at ' + @FileName);

        PRINT '✗ VERIFICATION FAILED: ' + @VerifyError;

        -- Send Telegram alert for backup verification failure
        IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC dbo.usp_SendTelegramAlert
                @Severity = N'CRITICAL',
                @Title = N'Backup Verification FAILED',
                @Message = @VerifyError;

        RAISERROR('Backup verification failed for %s: %s', 16, 1, @FileName, @VerifyError);
    END CATCH;
END
GO

PRINT '✓ Shared backup procedure usp_PerformBackup created (with RESTORE VERIFYONLY)';
GO

-- Execute full backup
USE master;
GO

EXEC HospitalBackupDemo.dbo.usp_PerformBackup @BackupType = 'FULL';
GO
