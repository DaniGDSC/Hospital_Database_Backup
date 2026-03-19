-- Stored procedure for sending Telegram alerts from SQL Server
-- Calls send_telegram.sh via xp_cmdshell
-- Never raises errors — alerting must not break operations
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SendTelegramAlert;
GO

CREATE PROCEDURE dbo.usp_SendTelegramAlert
    @Severity NVARCHAR(10),   -- CRITICAL, WARNING, INFO
    @Title    NVARCHAR(200),
    @Message  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Cmd NVARCHAR(4000);
    DECLARE @ScriptPath NVARCHAR(500) = '/home/un1/project/Hospital_Database_Backup-main/scripts/utilities/send_telegram.sh';
    DECLARE @Result INT;

    BEGIN TRY
        -- Build shell command (escape single quotes in message)
        SET @Message = REPLACE(@Message, '''', '''''');
        SET @Title = REPLACE(@Title, '''', '''''');

        SET @Cmd = @ScriptPath + ' "' + @Severity + '" "' + @Title + '" "' + @Message + '"';

        EXEC @Result = xp_cmdshell @Cmd, NO_OUTPUT;

        -- Log the attempt to AuditLog
        INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'TELEGRAM_ALERT', 'dbo', 0, 'INSERT', 'ALERT_SENT',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(),
             CASE WHEN @Result = 0 THEN 1 ELSE 0 END,
             'Low',
             'Telegram [' + @Severity + ']: ' + @Title);

    END TRY
    BEGIN CATCH
        -- Never raise — alerting failure must not block operations
        PRINT 'Telegram alert failed (non-fatal): ' + ERROR_MESSAGE();
    END CATCH;
END;
GO

PRINT '✓ Stored procedure usp_SendTelegramAlert created';
GO
