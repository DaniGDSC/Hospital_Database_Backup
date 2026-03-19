-- SQL Server patch level verification
-- Checks current build against minimum required CU
-- Logs result to CapacityHistory for trend tracking
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         SQL Server Patch Level Check                            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @Version NVARCHAR(200) = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(200));
DECLARE @Level NVARCHAR(50) = CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(50));
DECLARE @CU NVARCHAR(50) = ISNULL(CAST(SERVERPROPERTY('ProductUpdateLevel') AS NVARCHAR(50)), 'None');
DECLARE @Edition NVARCHAR(100) = CAST(SERVERPROPERTY('Edition') AS NVARCHAR(100));
DECLARE @MinBuild NVARCHAR(20) = '16.0.4085'; -- CU14 minimum

PRINT 'SQL Server Version: ' + @Version;
PRINT 'Product Level:      ' + @Level;
PRINT 'Cumulative Update:  ' + @CU;
PRINT 'Edition:            ' + @Edition;
PRINT '';

-- Check if build meets minimum
DECLARE @BuildOK BIT = 0;
IF @Version >= @MinBuild
    SET @BuildOK = 1;

IF @BuildOK = 1
BEGIN
    PRINT '✓ PASS: Build ' + @Version + ' meets minimum (' + @MinBuild + ')';
END
ELSE
BEGIN
    PRINT '✗ FAIL: Build ' + @Version + ' below minimum (' + @MinBuild + ')';
    PRINT '  Action: Apply CU14 or later';

    -- Send alert if Telegram procedure exists
    IF OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
        EXEC dbo.usp_SendTelegramAlert
            @Severity = N'WARNING',
            @Title = N'SQL Server Patch Outdated',
            @Message = @Version;
END

-- Log to AuditLog
INSERT INTO dbo.AuditLog
    (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
     UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
VALUES
    (SYSDATETIME(), 'PATCH_CHECK', 'dbo', 0, 'SELECT', 'PATCH_VERIFY',
     SUSER_SNAME(), HOST_NAME(), APP_NAME(), @BuildOK,
     CASE WHEN @BuildOK = 1 THEN 'Low' ELSE 'High' END,
     'SQL Server ' + @Version + ' CU=' + @CU + ' Edition=' + @Edition
     + ' MinRequired=' + @MinBuild);

PRINT '';
PRINT '✓ Patch check logged to AuditLog';
GO
