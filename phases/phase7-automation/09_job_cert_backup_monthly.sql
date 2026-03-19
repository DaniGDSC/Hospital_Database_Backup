-- Phase 7: Monthly TDE Certificate Backup Job
-- Purpose: Re-export TDE certificate and upload encrypted copy to S3
-- Schedule: First Sunday of each month at 02:00 AM
-- CRITICAL: Without this, server loss = permanent data loss

USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

-- Create the stored procedure for certificate backup
IF OBJECT_ID('dbo.usp_BackupCertificate', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_BackupCertificate;
GO

CREATE PROCEDURE dbo.usp_BackupCertificate
    @CertBackupPassword NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @CertFile NVARCHAR(260) = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.cer';
    DECLARE @KeyFile  NVARCHAR(260) = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.pvk';

    BEGIN TRY
        -- Verify certificate exists
        IF NOT EXISTS (SELECT 1 FROM master.sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
        BEGIN
            RAISERROR('TDE certificate not found in master', 16, 1);
            RETURN;
        END

        -- Validate password
        IF @CertBackupPassword IS NULL OR LEN(@CertBackupPassword) < 12
        BEGIN
            RAISERROR('Certificate backup password must be at least 12 characters', 16, 1);
            RETURN;
        END

        -- Re-export certificate (overwrites previous local copy)
        DECLARE @Sql NVARCHAR(MAX) = N'
            USE master;
            BACKUP CERTIFICATE HospitalBackupDemo_TDECert
                TO FILE = ''' + @CertFile + N'''
                WITH PRIVATE KEY (
                    FILE = ''' + @KeyFile + N''',
                    ENCRYPTION BY PASSWORD = ''' + @CertBackupPassword + N'''
                );';
        EXEC sp_executesql @Sql;

        PRINT '✓ Certificate exported to disk';

        -- Verify files exist
        DECLARE @CerExists INT, @PvkExists INT;
        EXEC master.dbo.xp_fileexist @CertFile, @CerExists OUTPUT;
        EXEC master.dbo.xp_fileexist @KeyFile, @PvkExists OUTPUT;

        IF @CerExists = 0 OR @PvkExists = 0
        BEGIN
            RAISERROR('Certificate export succeeded but files not found on disk', 16, 1);
            RETURN;
        END

        -- Log success to AuditLog
        INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'sys.certificates', 'master', 0, 'SELECT', 'CERT_BACKUP',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1, 'Low',
             'Monthly TDE certificate backup completed successfully');

        PRINT '✓ Certificate backup logged to AuditLog';
        PRINT 'Next: Run backup_cert_to_s3.sh to upload to S3';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'CRITICAL ERROR: ' + @ErrorMessage;

        INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'sys.certificates', 'master', 0, 'SELECT', 'CERT_BACKUP',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
             'CERT BACKUP FAILED: ' + @ErrorMessage);

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '✓ Stored procedure usp_BackupCertificate created';
GO

-- Create the SQL Agent Job
USE msdb;
GO

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Monthly_CertBackup')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Monthly_CertBackup', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Monthly_CertBackup',
    @enabled = 1,
    @description = N'Monthly TDE certificate re-export and S3 upload',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance',
    @notify_level_email = 2; -- Notify on failure
GO

-- Step 1: Re-export certificate to disk
-- NOTE: CERT_BACKUP_PASSWORD must be set in the SQL Agent proxy or CmdExec environment
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Monthly_CertBackup',
    @step_name = N'Export_Certificate',
    @step_id = 1,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_BackupCertificate @CertBackupPassword = N''$(ESCAPE_SQUOTE(STRTDT))'';
-- IMPORTANT: Replace above with actual password retrieval from secrets manager
-- For production: Use a SQL Agent proxy with credential that holds the password
-- Example with env var: EXEC dbo.usp_BackupCertificate @CertBackupPassword = N''$(CERT_BACKUP_PASSWORD)'';',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2; -- Quit with failure
GO

-- Step 2: Upload encrypted certificate to S3
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Monthly_CertBackup',
    @step_name = N'Upload_To_S3',
    @step_id = 2,
    @subsystem = N'CmdExec',
    @command = N'/home/un1/project/Hospital_Database_Backup-main/scripts/utilities/backup_cert_to_s3.sh',
    @retry_attempts = 2,
    @retry_interval = 10,
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2; -- Quit with failure
GO

-- Schedule: First Sunday of each month at 02:00 AM
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Monthly_FirstSunday_0200')
    EXEC sp_delete_schedule @schedule_name = N'Monthly_FirstSunday_0200', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Monthly_FirstSunday_0200',
    @freq_type = 32,        -- Monthly relative
    @freq_interval = 1,     -- Sunday
    @freq_relative_interval = 1, -- First
    @freq_recurrence_factor = 1, -- Every month
    @active_start_time = 020000; -- 02:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Monthly_CertBackup',
    @schedule_name = N'Monthly_FirstSunday_0200';
GO

-- Add notification operator
IF EXISTS (SELECT 1 FROM sysoperators WHERE name = 'DBA_Team')
    EXEC sp_update_job
        @job_name = N'HospitalBackup_Monthly_CertBackup',
        @notify_email_operator_name = N'DBA_Team';
GO

PRINT 'SQL Agent Job created: HospitalBackup_Monthly_CertBackup';
PRINT 'Schedule: First Sunday of each month at 02:00 AM';
PRINT 'IMPORTANT: Configure CERT_BACKUP_PASSWORD and CERT_S3_ENCRYPTION_KEY';
PRINT '  in the SQL Agent proxy environment before first run.';
GO
