-- SQL Agent Job: Monthly SQL Server Patch Check
-- Schedule: First Monday of month at 09:00 AM
USE msdb;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Monthly_Patch_Check')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Monthly_Patch_Check', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Monthly_Patch_Check',
    @enabled = 1,
    @description = N'Monthly SQL Server patch level verification and alerting',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Monthly_Patch_Check',
    @step_name = N'Check_Patch_Level',
    @step_id = 1,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'
DECLARE @Version NVARCHAR(200) = CAST(SERVERPROPERTY(''ProductVersion'') AS NVARCHAR(200));
DECLARE @CU NVARCHAR(50) = ISNULL(CAST(SERVERPROPERTY(''ProductUpdateLevel'') AS NVARCHAR(50)), ''None'');
DECLARE @MinBuild NVARCHAR(20) = ''16.0.4085'';

IF @Version < @MinBuild AND OBJECT_ID(''dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
    EXEC dbo.usp_SendTelegramAlert
        @Severity = N''WARNING'',
        @Title = N''Monthly Patch Check'',
        @Message = @Version;

INSERT INTO dbo.AuditLog
    (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
     UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
VALUES
    (SYSDATETIME(), ''PATCH_CHECK'', ''dbo'', 0, ''SELECT'', ''MONTHLY_PATCH_CHECK'',
     SUSER_SNAME(), HOST_NAME(), APP_NAME(),
     CASE WHEN @Version >= @MinBuild THEN 1 ELSE 0 END,
     ''Low'',
     ''Monthly check: '' + @Version + '' CU='' + @CU);

PRINT ''Monthly patch check complete: '' + @Version;
',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: First Monday of each month at 09:00
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Monthly_First_Monday_0900_Patch')
    EXEC sp_delete_schedule @schedule_name = N'Monthly_First_Monday_0900_Patch', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Monthly_First_Monday_0900_Patch',
    @freq_type = 32,         -- Monthly relative
    @freq_interval = 2,      -- Monday
    @freq_relative_interval = 1, -- First
    @freq_recurrence_factor = 1, -- Every month
    @active_start_time = 090000;
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Monthly_Patch_Check',
    @schedule_name = N'Monthly_First_Monday_0900_Patch';
GO

PRINT '✓ SQL Agent Job: HospitalBackup_Monthly_Patch_Check';
PRINT '  Schedule: First Monday of month at 09:00';
GO
