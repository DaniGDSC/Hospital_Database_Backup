-- SQL Agent Job: Daily Capacity Collection and Forecasting
-- Schedule: Daily at 23:00 (after backups complete)
-- Steps: Collect → Forecast → Alert
USE msdb;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sysjobs WHERE name = N'HospitalBackup_Daily_Capacity')
    EXEC sp_delete_job @job_name = N'HospitalBackup_Daily_Capacity', @delete_unused_schedule = 1;
GO

EXEC sp_add_job
    @job_name = N'HospitalBackup_Daily_Capacity',
    @enabled = 1,
    @description = N'Daily capacity metrics collection, forecasting, and alerting',
    @owner_login_name = N'sa',
    @category_name = N'Database Maintenance';
GO

-- Step 1: Collect metrics
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Daily_Capacity',
    @step_name = N'Collect_Metrics',
    @step_id = 1,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_CollectCapacityMetrics;',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

-- Step 2: Generate forecast
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Daily_Capacity',
    @step_name = N'Generate_Forecast',
    @step_id = 2,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_ForecastCapacity @BasisDays = 30;',
    @on_success_action = 3,
    @on_fail_action = 3;
GO

-- Step 3: Check alerts
EXEC sp_add_jobstep
    @job_name = N'HospitalBackup_Daily_Capacity',
    @step_name = N'Check_Alerts',
    @step_id = 3,
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'EXEC dbo.usp_CheckCapacityAlerts;',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Daily at 23:00
IF EXISTS (SELECT 1 FROM sysschedules WHERE name = N'Daily_2300_Capacity')
    EXEC sp_delete_schedule @schedule_name = N'Daily_2300_Capacity', @force_delete = 1;
GO

EXEC sp_add_schedule
    @schedule_name = N'Daily_2300_Capacity',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 230000;
GO

EXEC sp_attach_schedule
    @job_name = N'HospitalBackup_Daily_Capacity',
    @schedule_name = N'Daily_2300_Capacity';
GO

PRINT '✓ SQL Agent Job: HospitalBackup_Daily_Capacity';
PRINT '  Schedule: Daily at 23:00';
PRINT '  Steps: Collect → Forecast → Alert';
GO
