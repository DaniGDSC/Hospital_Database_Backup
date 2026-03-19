-- SQL Agent Job: TLS Certificate Expiry Check
-- HIPAA 45 CFR 164.312(e)(1): Transmission Security
-- Schedule: Weekly Monday 08:00 AM
-- Alerts: WARNING at <60 days, CRITICAL at <30 days
USE msdb;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_TLS_Cert_Check')
    EXEC sp_delete_job @job_name = N'HospitalBackup_TLS_Cert_Check', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_TLS_Cert_Check',
    @enabled = 1,
    @description = N'Weekly TLS certificate expiry check (HIPAA transmission security)',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Step 1: Check TLS cert expiry via xp_cmdshell
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_TLS_Cert_Check',
    @step_name = N'Check_TLS_Cert_Expiry',
    @step_id = 1,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'
DECLARE @CertFile NVARCHAR(500) = N''/var/opt/mssql/tls/mssql.pem'';
DECLARE @Cmd NVARCHAR(4000);
DECLARE @Output TABLE (line NVARCHAR(500));
DECLARE @ExpiryStr NVARCHAR(200);
DECLARE @DaysLeft INT;

-- Check if cert file exists
SET @Cmd = N''openssl x509 -in '' + @CertFile + N'' -noout -enddate 2>/dev/null'';
INSERT INTO @Output EXEC xp_cmdshell @Cmd;

SELECT TOP 1 @ExpiryStr = line FROM @Output WHERE line LIKE ''notAfter=%'';

IF @ExpiryStr IS NULL
BEGIN
    -- Cert file not found or unreadable
    IF OBJECT_ID(''dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
        EXEC dbo.usp_SendTelegramAlert
            @Severity = N''WARNING'',
            @Title = N''TLS Cert Check'',
            @Message = N''TLS certificate file not found or unreadable'';
    PRINT ''WARNING: TLS certificate not found'';
    RETURN;
END

-- Parse days remaining via openssl
DELETE FROM @Output;
SET @Cmd = N''openssl x509 -in '' + @CertFile + N'' -checkend 2592000 -noout 2>&1'';
INSERT INTO @Output EXEC xp_cmdshell @Cmd;

-- checkend returns "Certificate will expire" if within threshold
IF EXISTS (SELECT 1 FROM @Output WHERE line LIKE ''%will expire%'')
BEGIN
    -- Less than 30 days — CRITICAL
    IF OBJECT_ID(''dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
        EXEC dbo.usp_SendTelegramAlert
            @Severity = N''CRITICAL'',
            @Title = N''TLS Certificate Expiring'',
            @Message = N''TLS certificate expires within 30 days. Renew immediately.'';

    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
         UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
    VALUES
        (SYSDATETIME(), ''TLS_CERT_CHECK'', ''dbo'', 0, ''SELECT'', ''CERT_EXPIRY'',
         SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, ''Critical'',
         ''TLS certificate expires within 30 days'');

    PRINT ''CRITICAL: TLS certificate expires within 30 days'';
END
ELSE
BEGIN
    -- Check 60-day threshold
    DELETE FROM @Output;
    SET @Cmd = N''openssl x509 -in '' + @CertFile + N'' -checkend 5184000 -noout 2>&1'';
    INSERT INTO @Output EXEC xp_cmdshell @Cmd;

    IF EXISTS (SELECT 1 FROM @Output WHERE line LIKE ''%will expire%'')
    BEGIN
        IF OBJECT_ID(''dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
            EXEC dbo.usp_SendTelegramAlert
                @Severity = N''WARNING'',
                @Title = N''TLS Certificate Expiring'',
                @Message = N''TLS certificate expires within 60 days. Plan renewal.'';

        PRINT ''WARNING: TLS certificate expires within 60 days'';
    END
    ELSE
        PRINT ''OK: TLS certificate valid for more than 60 days'';
END
',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Weekly Monday 08:00 AM
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Weekly_Monday_8AM_TLS')
    EXEC sp_delete_schedule @schedule_name = N'Weekly_Monday_8AM_TLS', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Weekly_Monday_8AM_TLS',
    @freq_type = 8,          -- Weekly
    @freq_interval = 2,      -- Monday
    @active_start_time = 080000; -- 08:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_TLS_Cert_Check',
    @schedule_name = N'Weekly_Monday_8AM_TLS';
GO

PRINT '✓ SQL Agent Job: HospitalBackup_TLS_Cert_Check';
PRINT '  Schedule: Monday at 08:00 AM';
PRINT '  Alerts: WARNING at <60 days, CRITICAL at <30 days';
GO
