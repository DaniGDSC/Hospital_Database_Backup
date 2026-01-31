-- SQL Agent Job: Automated Disaster Recovery (OPTIONAL - REQUIRES MANUAL ENABLE)
-- Purpose: Automatically restore HospitalBackupDemo from cloud backup when disaster detected
-- Schedule: On-demand only (triggered by disaster detection job or manual execution)
-- Safety: Includes pre-checks; requires explicit enable flag

USE msdb;
GO

-- Drop existing job if present
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'HospitalBackup_AutoRecovery')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = 'HospitalBackup_AutoRecovery';
    PRINT 'Existing job dropped.';
END
GO

-- Create job (DISABLED by default for safety)
EXEC msdb.dbo.sp_add_job
    @job_name = 'HospitalBackup_AutoRecovery',
    @enabled = 0, -- DISABLED by default; enable only after testing
    @description = 'Automatic disaster recovery: restores HospitalBackupDemo from latest cloud backup',
    @category_name = 'Database Maintenance',
    @owner_login_name = 'sa';
GO

-- Step 1: Safety checks before recovery
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'HospitalBackup_AutoRecovery',
    @step_name = 'Pre-Recovery Safety Checks',
    @subsystem = 'TSQL',
    @database_name = 'master',
    @command = N'
SET NOCOUNT ON;

DECLARE @dbName SYSNAME = N''HospitalBackupDemo'';
DECLARE @autoRecoveryEnabled BIT = 0; -- SAFETY FLAG: Set to 1 to enable auto-recovery

-- Safety gate: Auto-recovery must be explicitly enabled
IF @autoRecoveryEnabled = 0
BEGIN
    RAISERROR(''Auto-recovery is DISABLED. To enable, set @autoRecoveryEnabled = 1 in job step.'', 16, 1);
    RETURN;
END

-- Check if database exists and is ONLINE
IF EXISTS (
    SELECT 1 FROM sys.databases 
    WHERE name = @dbName AND state = 0 -- 0 = ONLINE
)
BEGIN
    RAISERROR(''Database [%s] is ONLINE. Auto-recovery aborted (no disaster detected).'', 10, 1, @dbName);
    RETURN;
END

-- Check if S3 credential exists
IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = ''S3_HospitalBackupDemo'')
BEGIN
    RAISERROR(''S3 credential not found. Cannot proceed with cloud recovery.'', 16, 1);
    RETURN;
END

PRINT ''✓ Safety checks passed. Proceeding with auto-recovery...'';
',
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2;     -- Quit with failure
GO

-- Step 2: Download latest backup from S3
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'HospitalBackup_AutoRecovery',
    @step_name = 'Download Latest S3 Backup',
    @subsystem = 'CmdExec',
    @command = N'aws s3 cp s3://hospital-backup-prod-lock/backups/ /tmp/auto_recovery_latest.bak --recursive --exclude "*" --include "HospitalBackupDemo_FULL_*.bak" --region ap-southeast-1 | tail -1 && sudo cp /tmp/auto_recovery_latest.bak /var/opt/mssql/backup/disaster-recovery-drill/AUTO_RECOVERY.bak && sudo chown mssql:mssql /var/opt/mssql/backup/disaster-recovery-drill/AUTO_RECOVERY.bak',
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2;     -- Quit with failure
GO

-- Step 3: Execute restore
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'HospitalBackup_AutoRecovery',
    @step_name = 'Restore Database from Backup',
    @subsystem = 'TSQL',
    @database_name = 'master',
    @command = N'
SET NOCOUNT ON;

DECLARE @dbName SYSNAME = N''HospitalBackupDemo'';
DECLARE @backupFile NVARCHAR(500) = N''/var/opt/mssql/backup/disaster-recovery-drill/AUTO_RECOVERY.bak'';
DECLARE @dataPath NVARCHAR(260) = N''/var/opt/mssql/data/HospitalBackupDemo_Data.mdf'';
DECLARE @dataPath2 NVARCHAR(260) = N''/var/opt/mssql/data/HospitalBackupDemo_Data2.ndf'';
DECLARE @logPath NVARCHAR(260) = N''/var/opt/mssql/data/HospitalBackupDemo_Log.ldf'';

PRINT ''Starting automated restore from: '' + @backupFile;

-- Drop database if exists (disaster scenario: database is already missing)
IF DB_ID(@dbName) IS NOT NULL
BEGIN
    EXEC(''ALTER DATABASE ['' + @dbName + ''] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'');
    EXEC(''DROP DATABASE ['' + @dbName + '']'');
    PRINT ''Dropped existing database instance.'';
END

-- Restore with RECOVERY to bring online immediately
RESTORE DATABASE [HospitalBackupDemo]
    FROM DISK = @backupFile
    WITH MOVE ''HospitalBackupDemo_Data'' TO @dataPath,
         MOVE ''HospitalBackupDemo_Data2'' TO @dataPath2,
         MOVE ''HospitalBackupDemo_Log'' TO @logPath,
         REPLACE, RECOVERY, STATS = 10, CHECKSUM;

PRINT ''✓ Automated recovery completed: '' + @dbName + '' is now ONLINE.'';
',
    @on_success_action = 3, -- Go to next step
    @on_fail_action = 2;     -- Quit with failure
GO

-- Step 4: Post-recovery validation
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'HospitalBackup_AutoRecovery',
    @step_name = 'Validate Restored Database',
    @subsystem = 'TSQL',
    @database_name = 'master',
    @command = N'
SET NOCOUNT ON;

DECLARE @dbName SYSNAME = N''HospitalBackupDemo'';
DECLARE @state NVARCHAR(60);
DECLARE @recoveryModel NVARCHAR(60);

SELECT 
    @state = state_desc,
    @recoveryModel = recovery_model_desc
FROM sys.databases 
WHERE name = @dbName;

IF @state IS NULL
BEGIN
    RAISERROR(''VALIDATION FAILED: Database not found after restore.'', 16, 1);
    RETURN;
END

IF @state <> ''ONLINE''
BEGIN
    RAISERROR(''VALIDATION FAILED: Database is %s (expected ONLINE).'', 16, 1, @state);
    RETURN;
END

-- Log successful recovery
DECLARE @msg NVARCHAR(4000) = ''AUTO-RECOVERY SUCCESS: Database ['' + @dbName + ''] restored and verified ONLINE at '' + CONVERT(NVARCHAR(30), GETDATE(), 121);
RAISERROR(@msg, 10, 1) WITH LOG;

IF OBJECT_ID(''tempdb.dbo.DisasterDetectionLog'') IS NOT NULL
BEGIN
    INSERT INTO tempdb.dbo.DisasterDetectionLog (DatabaseName, EventType, StateDescription, Message)
    VALUES (@dbName, ''AUTO_RECOVERY'', ''SUCCESS'', @msg);
END

PRINT ''✓ Database validation passed: '' + @dbName + '' ('' + @state + '', '' + @recoveryModel + '')'';
',
    @on_success_action = 1, -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- NO SCHEDULE: This job is triggered manually or by disaster detection job
-- To enable automatic triggering, uncomment the sp_start_job call in 07_job_disaster_detection.sql

-- Assign to local server
EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'HospitalBackup_AutoRecovery',
    @server_name = '(local)';
GO

PRINT '✓ Job created: HospitalBackup_AutoRecovery (DISABLED by default)';
PRINT '  Trigger: Manual execution or called by disaster detection job';
PRINT '  Action: Downloads latest S3 backup and restores HospitalBackupDemo';
PRINT '';
PRINT '  ⚠ SAFETY NOTICE:';
PRINT '    1. This job is DISABLED (@enabled = 0) for safety.';
PRINT '    2. To enable auto-recovery:';
PRINT '       a) Set @autoRecoveryEnabled = 1 in Step 1 (Pre-Recovery Safety Checks)';
PRINT '       b) Enable the job: EXEC msdb.dbo.sp_update_job @job_name=''HospitalBackup_AutoRecovery'', @enabled=1;';
PRINT '       c) Uncomment sp_start_job call in 07_job_disaster_detection.sql';
PRINT '    3. Test thoroughly in non-production environment first.';
GO
