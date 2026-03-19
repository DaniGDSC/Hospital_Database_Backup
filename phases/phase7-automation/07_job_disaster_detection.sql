-- SQL Agent Job: Continuous Database Availability Monitoring
-- Purpose: Detect when HospitalBackupDemo goes offline and alert administrators
-- Schedule: Every 5 minutes (288 times/day)
-- Alert: Email + log entry when database becomes unavailable

USE msdb;
GO

-- Drop existing job if present
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'HospitalBackup_Disaster_Detection')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = 'HospitalBackup_Disaster_Detection';
    PRINT 'Existing job dropped.';
END
GO

-- Create job
EXEC msdb.dbo.sp_add_job
    @job_name = 'HospitalBackup_Disaster_Detection',
    @enabled = 1,
    @description = 'Monitors HospitalBackupDemo availability and detects disasters',
    @category_name = 'Database Maintenance',
    @owner_login_name = 'sa';
GO

-- Step 1: Check database status and log if offline
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'HospitalBackup_Disaster_Detection',
    @step_name = 'Monitor Database Availability',
    @subsystem = 'TSQL',
    @database_name = 'master',
    @command = N'
SET NOCOUNT ON;

DECLARE @dbName SYSNAME = N''HospitalBackupDemo'';
DECLARE @state INT;
DECLARE @stateDesc NVARCHAR(60);
DECLARE @alertMsg NVARCHAR(4000);
DECLARE @lastState NVARCHAR(60);

-- Check current database state
SELECT 
    @state = state,
    @stateDesc = state_desc
FROM sys.databases 
WHERE name = @dbName;

-- If database does not exist, treat as CRITICAL disaster
IF @state IS NULL
BEGIN
    SET @alertMsg = ''CRITICAL DISASTER DETECTED: Database ['' + @dbName + ''] does not exist in sys.databases. Last check: '' + CONVERT(NVARCHAR(30), GETDATE(), 121);
    
    -- Log to SQL Server error log
    RAISERROR(@alertMsg, 16, 1) WITH LOG;
    
    -- Log to application table (if it exists)
    IF OBJECT_ID(''tempdb.dbo.DisasterDetectionLog'') IS NULL
    BEGIN
        CREATE TABLE tempdb.dbo.DisasterDetectionLog (
            LogID INT IDENTITY(1,1) PRIMARY KEY,
            EventTime DATETIME2 DEFAULT GETDATE(),
            DatabaseName SYSNAME,
            EventType NVARCHAR(50),
            StateDescription NVARCHAR(100),
            Message NVARCHAR(4000)
        );
    END
    
    INSERT INTO tempdb.dbo.DisasterDetectionLog (DatabaseName, EventType, StateDescription, Message)
    VALUES (@dbName, ''DISASTER'', ''DATABASE_MISSING'', @alertMsg);

    -- Telegram: database missing — critical disaster
    IF OBJECT_ID(''HospitalBackupDemo.dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
        EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
            @Severity = N''CRITICAL'',
            @Title = N''DISASTER: Database Missing'',
            @Message = @alertMsg;

    RETURN; -- Exit; disaster logged
END

-- If database exists but is not ONLINE, log warning
IF @state <> 0 -- 0 = ONLINE
BEGIN
    SET @alertMsg = ''WARNING: Database ['' + @dbName + ''] is '' + @stateDesc + ''. Expected: ONLINE. Time: '' + CONVERT(NVARCHAR(30), GETDATE(), 121);
    
    RAISERROR(@alertMsg, 10, 1) WITH LOG;
    
    IF OBJECT_ID(''tempdb.dbo.DisasterDetectionLog'') IS NOT NULL
    BEGIN
        INSERT INTO tempdb.dbo.DisasterDetectionLog (DatabaseName, EventType, StateDescription, Message)
        VALUES (@dbName, ''WARNING'', @stateDesc, @alertMsg);
    END

    -- Telegram: database not ONLINE
    IF OBJECT_ID(''HospitalBackupDemo.dbo.usp_SendTelegramAlert'', ''P'') IS NOT NULL
        EXEC HospitalBackupDemo.dbo.usp_SendTelegramAlert
            @Severity = N''CRITICAL'',
            @Title = N''Database NOT ONLINE'',
            @Message = @alertMsg;
END
ELSE
BEGIN
    -- Database is ONLINE; no action needed (optional: log healthy status every hour)
    IF DATEPART(MINUTE, GETDATE()) IN (0, 30) -- Log health twice per hour
    BEGIN
        IF OBJECT_ID(''tempdb.dbo.DisasterDetectionLog'') IS NOT NULL
        BEGIN
            INSERT INTO tempdb.dbo.DisasterDetectionLog (DatabaseName, EventType, StateDescription, Message)
            VALUES (@dbName, ''HEALTHY'', ''ONLINE'', ''Database operational.'');
        END
    END
END
',
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- Schedule: Every 5 minutes, 24/7
EXEC msdb.dbo.sp_add_jobschedule
    @job_name = 'HospitalBackup_Disaster_Detection',
    @name = 'Every_5_Minutes',
    @freq_type = 4,              -- Daily
    @freq_interval = 1,          -- Every day
    @freq_subday_type = 4,       -- Minutes
    @freq_subday_interval = 5,   -- Every 5 minutes
    @active_start_time = 0;      -- Start at midnight
GO

-- Assign to local server
EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'HospitalBackup_Disaster_Detection',
    @server_name = '(local)';
GO

PRINT '✓ Job created: HospitalBackup_Disaster_Detection';
PRINT '  Schedule: Every 5 minutes';
PRINT '  Action: Monitors database availability; logs disasters to tempdb.dbo.DisasterDetectionLog';
PRINT '  Note: To enable auto-recovery, uncomment the sp_start_job call in the job step.';
GO
