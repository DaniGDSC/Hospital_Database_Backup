-- Validate restored databases with CHECKDB + smoke tests
-- Runs against all recovery databases that exist
-- Used by: weekly DR drill, manual recovery validation
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Recovery Validation ===';
PRINT '';

DECLARE @dbs TABLE (DbName SYSNAME);
INSERT INTO @dbs(DbName) VALUES
    ('HospitalBackupDemo_Recovery'),
    ('HospitalBackupDemo_PITR'),
    ('HospitalBackupDemo_FromS3');

DECLARE @db SYSNAME;
DECLARE @sql NVARCHAR(MAX);
DECLARE @passCount INT = 0;
DECLARE @failCount INT = 0;
DECLARE @skipCount INT = 0;

DECLARE db_cursor CURSOR FAST_FORWARD FOR
    SELECT DbName FROM @dbs;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF DB_ID(@db) IS NULL
    BEGIN
        PRINT '--- ' + @db + ': SKIPPED (not found)';
        SET @skipCount = @skipCount + 1;
        FETCH NEXT FROM db_cursor INTO @db;
        CONTINUE;
    END

    PRINT '--- Validating: ' + @db;

    BEGIN TRY
        -- DBCC CHECKDB — verify physical and logical integrity
        SET @sql = N'DBCC CHECKDB(''' + @db + N''') WITH NO_INFOMSGS;';
        EXEC (@sql);
        PRINT '  ✓ CHECKDB passed';

        -- Row counts for key tables
        SET @sql = N'
            SELECT ''Patients'' AS TableName, COUNT(*) AS Rows FROM ' + QUOTENAME(@db) + N'.dbo.Patients
            UNION ALL
            SELECT ''Appointments'', COUNT(*) FROM ' + QUOTENAME(@db) + N'.dbo.Appointments
            UNION ALL
            SELECT ''Billing'', COUNT(*) FROM ' + QUOTENAME(@db) + N'.dbo.Billing;
        ';
        EXEC (@sql);
        PRINT '  ✓ Row counts verified';

        SET @passCount = @passCount + 1;
    END TRY
    BEGIN CATCH
        DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT '  ✗ VALIDATION FAILED: ' + @err;
        SET @failCount = @failCount + 1;

        -- Log failure to source database
        IF OBJECT_ID('HospitalBackupDemo.dbo.AuditLog', 'U') IS NOT NULL
        BEGIN
            INSERT INTO HospitalBackupDemo.dbo.AuditLog
                (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
                 UserName, HostName, ApplicationName, IsSuccess, Severity, ErrorMessage, Notes)
            VALUES
                (SYSDATETIME(), 'RECOVERY_VALIDATION', 'dbo', 0, 'SELECT', 'VALIDATE_FAILED',
                 SUSER_SNAME(), HOST_NAME(), APP_NAME(), 0, 'Critical',
                 @err, 'Validation failed for ' + @db);
        END

        IF OBJECT_ID('HospitalBackupDemo.dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
                @Severity = N'CRITICAL',
                @Title = N'Recovery Validation FAILED',
                @Message = @err;
    END CATCH

    FETCH NEXT FROM db_cursor INTO @db;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '  PASS:    ' + CAST(@passCount AS NVARCHAR);
PRINT '  FAIL:    ' + CAST(@failCount AS NVARCHAR);
PRINT '  SKIPPED: ' + CAST(@skipCount AS NVARCHAR);
PRINT '═══════════════════════════════════════════════════';

IF @failCount > 0
    RAISERROR('Recovery validation: %d database(s) failed.', 16, 1, @failCount);
ELSE IF @passCount > 0
    PRINT '✓ All restored databases validated successfully';
ELSE
    PRINT '⚠ No recovery databases found to validate';
GO
