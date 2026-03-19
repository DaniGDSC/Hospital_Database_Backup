-- Enforce automatic session timeout for idle connections
-- HIPAA 45 CFR 164.312(a)(2)(iii): Automatic Logoff
-- "Implement electronic procedures that terminate an electronic
--  session after a predetermined time of inactivity."
--
-- Reads timeout from: dbo.SystemConfiguration WHERE ConfigKey='SessionTimeoutMinutes'
-- Excludes: sa, system accounts, SQL Agent sessions
-- Requires: sysadmin (to KILL sessions)
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║     Session Timeout Enforcement (HIPAA 164.312(a)(2)(iii))     ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Part 1: Stored Procedure
-- ============================================

IF OBJECT_ID('dbo.usp_EnforceSessionTimeout', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_EnforceSessionTimeout;
GO

CREATE PROCEDURE dbo.usp_EnforceSessionTimeout
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TimeoutMinutes INT;
    DECLARE @SessionID INT;
    DECLARE @LoginName NVARCHAR(128);
    DECLARE @IdleMinutes INT;
    DECLARE @ProgramName NVARCHAR(128);
    DECLARE @KillCount INT = 0;
    DECLARE @KillSql NVARCHAR(50);

    -- Read configurable timeout from SystemConfiguration
    SELECT @TimeoutMinutes = CAST(ConfigValue AS INT)
    FROM dbo.SystemConfiguration
    WHERE ConfigKey = 'SessionTimeoutMinutes' AND IsActive = 1;

    -- Default to 30 minutes if not configured
    SET @TimeoutMinutes = ISNULL(@TimeoutMinutes, 30);

    -- Find idle user sessions exceeding the timeout
    DECLARE session_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            s.session_id,
            s.login_name,
            s.program_name,
            DATEDIFF(MINUTE, s.last_request_end_time, SYSDATETIME()) AS IdleMinutes
        FROM sys.dm_exec_sessions s
        WHERE s.is_user_process = 1
          AND s.status = 'sleeping'
          AND s.last_request_end_time IS NOT NULL
          AND DATEDIFF(MINUTE, s.last_request_end_time, SYSDATETIME()) > @TimeoutMinutes
          -- Exclude system and service accounts
          AND s.login_name NOT IN ('sa')
          AND s.login_name NOT LIKE 'NT %'
          AND s.login_name NOT LIKE '##%'
          AND s.program_name NOT LIKE 'SQLAgent%'
          AND s.program_name NOT LIKE 'Microsoft SQL Server%';

    OPEN session_cursor;
    FETCH NEXT FROM session_cursor INTO @SessionID, @LoginName, @ProgramName, @IdleMinutes;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Log the kill to AuditLog before execution
            INSERT INTO dbo.AuditLog
                (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
                 UserName, DatabaseUser, HostName, ApplicationName, IPAddress, SessionID,
                 IsSuccess, Severity, IsSecurityEvent, Notes)
            VALUES
                (SYSDATETIME(), 'SESSION_MANAGEMENT', 'dbo', @SessionID,
                 'DELETE', 'SESSION_TIMEOUT',
                 @LoginName, USER_NAME(), HOST_NAME(), @ProgramName,
                 CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
                 @@SPID,
                 1, 'Medium', 1,
                 'Session killed: SPID ' + CAST(@SessionID AS NVARCHAR(10))
                 + ', login ' + @LoginName
                 + ', idle ' + CAST(@IdleMinutes AS NVARCHAR(10)) + ' min'
                 + ', timeout ' + CAST(@TimeoutMinutes AS NVARCHAR(10)) + ' min');

            -- Log to SecurityAuditEvents
            INSERT INTO dbo.SecurityAuditEvents
                (EventTime, EventType, LoginName, DatabaseUser, ObjectName,
                 ObjectType, Action, Success, ClientHost, ApplicationName, Details)
            VALUES
                (SYSDATETIME(), 'SESSION_TIMEOUT', @LoginName, USER_NAME(),
                 'session_id=' + CAST(@SessionID AS NVARCHAR(10)),
                 'SESSION', 'KILL', 1, HOST_NAME(), @ProgramName,
                 'Idle session terminated after ' + CAST(@IdleMinutes AS NVARCHAR(10))
                 + ' minutes (threshold: ' + CAST(@TimeoutMinutes AS NVARCHAR(10)) + ')');

            -- Kill the idle session
            SET @KillSql = N'KILL ' + CAST(@SessionID AS NVARCHAR(10));
            EXEC sp_executesql @KillSql;

            SET @KillCount = @KillCount + 1;

            PRINT 'Killed session ' + CAST(@SessionID AS NVARCHAR(10))
                + ' (' + @LoginName + ', idle ' + CAST(@IdleMinutes AS NVARCHAR(10)) + ' min)';
        END TRY
        BEGIN CATCH
            PRINT 'Failed to kill session ' + CAST(@SessionID AS NVARCHAR(10))
                + ': ' + ERROR_MESSAGE();
        END CATCH

        FETCH NEXT FROM session_cursor INTO @SessionID, @LoginName, @ProgramName, @IdleMinutes;
    END

    CLOSE session_cursor;
    DEALLOCATE session_cursor;

    -- Send Telegram alert if any sessions were killed
    IF @KillCount > 0 AND OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
    BEGIN
        DECLARE @Msg NVARCHAR(500) = CAST(@KillCount AS NVARCHAR(10))
            + ' idle session(s) terminated (timeout: '
            + CAST(@TimeoutMinutes AS NVARCHAR(10)) + ' min)';
        EXEC dbo.usp_SendTelegramAlert
            @Severity = N'WARNING',
            @Title = N'Session Timeout Enforcement',
            @Message = @Msg;
    END

    PRINT 'Session timeout enforcement complete. Killed: ' + CAST(@KillCount AS NVARCHAR(10));
END;
GO

PRINT '✓ Stored procedure usp_EnforceSessionTimeout created';
GO

-- ============================================
-- Part 2: SQL Agent Job (every 5 minutes)
-- ============================================

USE msdb;
GO

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Session_Timeout')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Session_Timeout', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Session_Timeout',
    @enabled = 1,
    @description = N'HIPAA 164.312(a)(2)(iii): Kill idle sessions exceeding configured timeout',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Session_Timeout',
    @step_name = N'Enforce_Timeout',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_EnforceSessionTimeout;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Every 5 minutes
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Every_5_Minutes_SessionTimeout')
    EXEC sp_delete_schedule @schedule_name = N'Every_5_Minutes_SessionTimeout', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Every_5_Minutes_SessionTimeout',
    @freq_type = 4,            -- Daily
    @freq_interval = 1,        -- Every day
    @freq_subday_type = 4,     -- Minutes
    @freq_subday_interval = 5, -- Every 5 minutes
    @active_start_time = 0;    -- Start at midnight
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Session_Timeout',
    @schedule_name = N'Every_5_Minutes_SessionTimeout';
GO

PRINT '✓ SQL Agent Job: HospitalBackup_Session_Timeout (every 5 min)';
PRINT '  Test: EXEC sp_start_job @job_name = ''HospitalBackup_Session_Timeout'';';
GO
