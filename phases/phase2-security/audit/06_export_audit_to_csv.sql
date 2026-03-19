-- Export audit logs to CSV for nightly S3 upload
-- HIPAA 45 CFR 164.530(j): Audit log retention minimum 6 years
-- Exports yesterday's records from all 3 audit tables via BCP
--
-- ⚠️ REQUIRES SA: BCP uses trusted connection via xp_cmdshell
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

IF OBJECT_ID('dbo.usp_ExportAuditLogs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ExportAuditLogs;
GO

CREATE PROCEDURE dbo.usp_ExportAuditLogs
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExportDir NVARCHAR(260) = '/var/opt/mssql/backup/audit-export';
    DECLARE @DateStr NVARCHAR(8) = CONVERT(NVARCHAR(8), DATEADD(DAY, -1, GETUTCDATE()), 112);
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @TotalRows INT = 0;

    -- Audit tables to export
    DECLARE @Tables TABLE (
        TableName NVARCHAR(128),
        DateColumn NVARCHAR(128)
    );
    INSERT INTO @Tables VALUES
        ('AuditLog', 'AuditDate'),
        ('SecurityAuditEvents', 'EventTime'),
        ('SecurityEvents', 'EventDate');

    DECLARE @TableName NVARCHAR(128);
    DECLARE @DateColumn NVARCHAR(128);
    DECLARE @FileName NVARCHAR(260);
    DECLARE @BcpCmd NVARCHAR(4000);
    DECLARE @RowCount INT;
    DECLARE @CmdResult INT;

    PRINT '=== Nightly Audit Log Export ===';
    PRINT 'Export date: ' + @DateStr + ' (yesterday UTC)';
    PRINT 'Export dir:  ' + @ExportDir;
    PRINT '';

    BEGIN TRY
        -- Ensure export directory exists
        EXEC xp_cmdshell 'mkdir -p /var/opt/mssql/backup/audit-export', NO_OUTPUT;

        DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT TableName, DateColumn FROM @Tables;
        OPEN table_cursor;
        FETCH NEXT FROM table_cursor INTO @TableName, @DateColumn;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @FileName = @ExportDir + '/audit_' + LOWER(@TableName) + '_' + @DateStr + '.csv';

            -- Check if export already exists for this date (idempotent)
            DECLARE @FileExists INT;
            EXEC master.dbo.xp_fileexist @FileName, @FileExists OUTPUT;

            IF @FileExists = 1
            BEGIN
                PRINT '  SKIP: ' + @FileName + ' already exists';
                FETCH NEXT FROM table_cursor INTO @TableName, @DateColumn;
                CONTINUE;
            END

            -- Count rows to export
            DECLARE @CountSql NVARCHAR(500) = N'SELECT @cnt = COUNT(*) FROM dbo.' + QUOTENAME(@TableName)
                + N' WHERE CAST(' + QUOTENAME(@DateColumn) + N' AS DATE) = CAST(DATEADD(DAY, -1, GETUTCDATE()) AS DATE)';
            EXEC sp_executesql @CountSql, N'@cnt INT OUTPUT', @cnt = @RowCount OUTPUT;

            IF @RowCount = 0
            BEGIN
                PRINT '  SKIP: ' + @TableName + ' — 0 rows for ' + @DateStr;
                FETCH NEXT FROM table_cursor INTO @TableName, @DateColumn;
                CONTINUE;
            END

            -- Build BCP export command
            -- Uses a query to filter by date, exports with column headers as CSV
            SET @BcpCmd = 'bcp "SELECT * FROM HospitalBackupDemo.dbo.' + @TableName
                + ' WHERE CAST(' + @DateColumn + ' AS DATE) = CAST(DATEADD(DAY, -1, GETUTCDATE()) AS DATE)'
                + '" queryout "' + @FileName + '"'
                + ' -S "127.0.0.1,14333" -U SA -P "' + '$(SQL_PASSWORD)' + '"'
                + ' -c -t "," -r "\n" -C 65001';

            PRINT '  Exporting: ' + @TableName + ' (' + CAST(@RowCount AS NVARCHAR) + ' rows) -> ' + @FileName;

            EXEC @CmdResult = xp_cmdshell @BcpCmd, NO_OUTPUT;

            IF @CmdResult = 0
            BEGIN
                PRINT '    ✓ Exported successfully';
                SET @TotalRows = @TotalRows + @RowCount;
            END
            ELSE
            BEGIN
                SET @ErrorMessage = 'BCP export failed for ' + @TableName;
                PRINT '    ✗ ' + @ErrorMessage;
                RAISERROR(@ErrorMessage, 16, 1);
            END

            FETCH NEXT FROM table_cursor INTO @TableName, @DateColumn;
        END

        CLOSE table_cursor;
        DEALLOCATE table_cursor;

        -- Log export completion to AuditLog
        INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
        VALUES
            (SYSDATETIME(), 'AUDIT_EXPORT', 'dbo', 0, 'SELECT', 'AUDIT_EXPORT',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 1, 'Low',
             'Nightly audit export completed: ' + CAST(@TotalRows AS NVARCHAR) + ' total rows for ' + @DateStr);

        PRINT '';
        PRINT '✓ Export complete: ' + CAST(@TotalRows AS NVARCHAR) + ' total rows';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'EXPORT ERROR: ' + @ErrorMessage;

        -- Log failure
        INSERT INTO dbo.AuditLog
            (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
             UserName, HostName, ApplicationName, IsSuccess, Severity,
             ErrorMessage, Notes)
        VALUES
            (SYSDATETIME(), 'AUDIT_EXPORT', 'dbo', 0, 'SELECT', 'AUDIT_EXPORT',
             SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
             @ErrorMessage, 'Nightly audit export FAILED for ' + @DateStr);

        -- Clean up cursor if still open
        IF CURSOR_STATUS('local', 'table_cursor') >= 0
        BEGIN
            CLOSE table_cursor;
            DEALLOCATE table_cursor;
        END

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '✓ Stored procedure usp_ExportAuditLogs created';
GO
