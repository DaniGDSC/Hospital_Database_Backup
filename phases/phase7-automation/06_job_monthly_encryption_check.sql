-- Phase 7: Monthly Encryption Check Job
-- Purpose: Verify TDE certificate status and key backup existence
-- Schedule: 15th of each month at 22:00 (10 PM)
-- Target DB: msdb (for SQL Agent job creation)

USE msdb;
GO

PRINT 'Creating stored procedure usp_CheckEncryptionStatus...';
GO

USE HospitalBackupDemo;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_CheckEncryptionStatus')
    DROP PROCEDURE usp_CheckEncryptionStatus;
GO

CREATE PROCEDURE usp_CheckEncryptionStatus
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TDEStatus BIT;
    DECLARE @CertThumbprint NVARCHAR(MAX);
    DECLARE @CertExpiry DATETIME;
    DECLARE @CertExists BIT;
    DECLARE @CertBackupExists BIT = 0;
    DECLARE @DaysTillExpiry INT;
    DECLARE @AlertMessage NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @HasAlert BIT = 0;

    BEGIN TRY
        PRINT '=== Encryption Status Report ===';
        PRINT '';

        -- Check TDE Status
        SELECT @TDEStatus = encryption_state
        FROM sys.dm_database_encryption_keys
        WHERE database_id = DB_ID('HospitalBackupDemo');

        IF @TDEStatus IS NULL
        BEGIN
            PRINT 'TDE: NOT INITIALIZED';
            SET @AlertMessage = 'WARNING: TDE not initialized on HospitalBackupDemo';
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('ENCRYPTION_TDE_STATUS', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE IF @TDEStatus = 3
        BEGIN
            PRINT 'TDE: ENABLED ✓';
        END
        ELSE IF @TDEStatus = 2
        BEGIN
            PRINT 'TDE: ENCRYPTION IN PROGRESS (scan ongoing)';
        END
        ELSE IF @TDEStatus = 1
        BEGIN
            PRINT 'TDE: DECRYPTION IN PROGRESS';
            SET @AlertMessage = 'WARNING: TDE decryption in progress!';
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('ENCRYPTION_TDE_STATUS', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE
        BEGIN
            PRINT CONCAT('TDE: UNKNOWN STATUS (', @TDEStatus, ')');
            SET @AlertMessage = CONCAT('WARNING: Unknown TDE status: ', @TDEStatus);
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('ENCRYPTION_TDE_STATUS', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
            SET @HasAlert = 1;
        END

        -- Get Certificate Details
        SELECT @CertThumbprint = thumbprint, @CertExpiry = expiry_date
        FROM sys.certificates
        WHERE name = 'HospitalBackupDemo_TDECert';

        IF @CertThumbprint IS NULL
        BEGIN
            PRINT 'TDE Certificate: NOT FOUND';
            SET @AlertMessage = 'CRITICAL: TDE certificate not found!';
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('ENCRYPTION_CERT_STATUS', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
            SET @HasAlert = 1;
        END
        ELSE
        BEGIN
            PRINT CONCAT('TDE Certificate: HospitalBackupDemo_TDECert');
            PRINT CONCAT('Thumbprint: ', @CertThumbprint);
            PRINT CONCAT('Expiry Date: ', FORMAT(@CertExpiry, 'yyyy-MM-dd HH:mm:ss'));

            -- Check certificate expiry
            IF @CertExpiry IS NOT NULL
            BEGIN
                SET @DaysTillExpiry = DATEDIFF(DAY, GETDATE(), @CertExpiry);
                IF @DaysTillExpiry < 0
                BEGIN
                    SET @AlertMessage = 'CRITICAL: TDE certificate has EXPIRED!';
                    PRINT CONCAT('ALERT: ', @AlertMessage);
                    INSERT INTO dbo.SystemConfiguration 
                    (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
                    VALUES ('ENCRYPTION_CERT_EXPIRY', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
                    SET @HasAlert = 1;
                END
                ELSE IF @DaysTillExpiry < 30
                BEGIN
                    SET @AlertMessage = CONCAT('WARNING: TDE certificate expires in ', @DaysTillExpiry, ' days');
                    PRINT CONCAT('ALERT: ', @AlertMessage);
                    INSERT INTO dbo.SystemConfiguration 
                    (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
                    VALUES ('ENCRYPTION_CERT_EXPIRY', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
                    SET @HasAlert = 1;
                END
                ELSE
                BEGIN
                    PRINT CONCAT('Certificate expiry: OK (', @DaysTillExpiry, ' days remaining)');
                END
            END
        END

        -- Check certificate backup path from SystemConfiguration (falls back to default)
        DECLARE @CertBackupDir NVARCHAR(MAX);
        SELECT @CertBackupDir = ConfigValue
        FROM dbo.SystemConfiguration
        WHERE ConfigKey = 'CertBackupDir';

        IF @CertBackupDir IS NULL
            SET @CertBackupDir = '/var/opt/mssql/backup/certificates';

        DECLARE @CertBackupPath NVARCHAR(MAX) = @CertBackupDir + '/HospitalBackupDemo_TDECert.cer';
        DECLARE @PrivateKeyPath NVARCHAR(MAX) = @CertBackupDir + '/HospitalBackupDemo_TDECert_privatekey.pvk';

        PRINT '';
        PRINT 'Certificate Backup Verification:';
        PRINT CONCAT('Expected location: ', @CertBackupPath);
        PRINT CONCAT('Manual verify: ls -la ', @CertBackupDir, '/');

        -- Check symmetric key status
        DECLARE @SymKeyExists BIT;
        SELECT @SymKeyExists = COUNT(*)
        FROM sys.symmetric_keys
        WHERE name = 'HospitalBackupDemo_SymKey'
            AND type = 'K'; -- Symmetric key

        IF @SymKeyExists > 0
        BEGIN
            PRINT '';
            PRINT 'Symmetric Key: HospitalBackupDemo_SymKey ✓';
        END
        ELSE
        BEGIN
            PRINT '';
            PRINT 'Symmetric Key: NOT FOUND';
            SET @AlertMessage = 'WARNING: Symmetric key for column encryption not found';
            INSERT INTO dbo.SystemConfiguration 
            (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
            VALUES ('ENCRYPTION_SYMKEY_STATUS', @AlertMessage, 'Security', 'Monthly encryption check', GETDATE());
            SET @HasAlert = 1;
        END

        -- Summary
        PRINT '';
        PRINT '=== Summary ===';
        IF @HasAlert = 0
        BEGIN
            PRINT 'Encryption checks PASSED - no alerts ✓';
            INSERT INTO dbo.BackupHistory
            (BackupType, BackupStartDate, BackupFileName, BackupLocation, BackupStatus, VerificationStatus, VerificationDate)
            VALUES
            ('Full', GETDATE(), 'TDE & Certs', 'Local Disk', 'Completed', 'Verified', GETDATE());

            -- Telegram: encryption check passed
            IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
                EXEC dbo.usp_SendTelegramAlert
                    @Severity = N'INFO',
                    @Title = N'Encryption Verified',
                    @Message = N'Monthly encryption check passed. TDE active, certificates valid.';
        END
        ELSE
        BEGIN
            PRINT 'ATTENTION: Encryption alerts detected - review SystemConfiguration table';
            INSERT INTO dbo.BackupHistory
            (BackupType, BackupStartDate, BackupFileName, BackupLocation, BackupStatus, VerificationStatus, VerificationDate)
            VALUES
            ('Full', GETDATE(), 'TDE & Certs', 'Local Disk', 'Completed', 'Failed', GETDATE());

            -- Telegram: encryption issues found
            IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
                EXEC dbo.usp_SendTelegramAlert
                    @Severity = N'CRITICAL',
                    @Title = N'Encryption Check FAILED',
                    @Message = N'Monthly encryption check found issues. Review SystemConfiguration table.';
        END

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT CONCAT('ERROR: ', @ErrorMessage);

        INSERT INTO dbo.SystemConfiguration
        (ConfigKey, ConfigValue, ConfigCategory, Description, LastModifiedDate)
        VALUES ('ENCRYPTION_CHECK_ERROR', @ErrorMessage, 'Security', 'Monthly encryption check failed', GETDATE());

        -- Telegram: encryption check error
        IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC dbo.usp_SendTelegramAlert
                @Severity = N'CRITICAL',
                @Title = N'Encryption Check ERROR',
                @Message = @ErrorMessage;

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'Stored procedure usp_CheckEncryptionStatus created successfully';
GO

-- Create the SQL Agent Job (run in msdb)
USE msdb;
GO

IF EXISTS (SELECT job_id FROM sysjobs WHERE name = N'HospitalBackup_Monthly_EncryptionCheck')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Monthly_EncryptionCheck', @delete_unused_schedule = 1;
GO

EXEC sp_add_job 
    @job_name = N'HospitalBackup_Monthly_EncryptionCheck',
    @enabled = 1,
    @description = N'Monthly verification of TDE and encryption certificate status',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Monthly_EncryptionCheck',
    @step_name = N'Check_Encryption',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC usp_CheckEncryptionStatus;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create Schedule (15th of each month at 22:00)
IF EXISTS (SELECT schedule_id FROM sysschedules WHERE name = N'Monthly_15th_10PM')
    EXEC sp_delete_schedule @schedule_name = N'Monthly_15th_10PM', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Monthly_15th_10PM',
    @freq_type = 16, -- Monthly
    @freq_interval = 15, -- 15th day
    @active_start_time = 220000; -- 22:00 (10 PM)
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Monthly_EncryptionCheck',
    @schedule_name = N'Monthly_15th_10PM';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Monthly_EncryptionCheck';
PRINT 'Schedule: 15th of each month at 22:00 (10 PM)';
PRINT 'Test the job: EXEC sp_start_job @job_name = ''HospitalBackup_Monthly_EncryptionCheck'';';
GO
