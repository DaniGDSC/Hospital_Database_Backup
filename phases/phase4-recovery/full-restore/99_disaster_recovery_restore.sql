-- Disaster recovery restore from downloaded S3 backup
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Restoring HospitalBackupDemo from S3 cloud backup ===';

-- Restore with explicit paths, RECOVERY to bring online
RESTORE DATABASE [HospitalBackupDemo]
    FROM DISK = N'/var/opt/mssql/backup/disaster-recovery-drill/DR_RESTORE.bak'
    WITH MOVE 'HospitalBackupDemo_Data' TO N'/var/opt/mssql/data/HospitalBackupDemo_Data.mdf',
         MOVE 'HospitalBackupDemo_Data2' TO N'/var/opt/mssql/data/HospitalBackupDemo_Data2.ndf',
         MOVE 'HospitalBackupDemo_Log' TO N'/var/opt/mssql/data/HospitalBackupDemo_Log.ldf',
         REPLACE, RECOVERY, STATS = 10, CHECKSUM;
GO

PRINT '✓ Restore completed: HospitalBackupDemo is now ONLINE.';
GO

-- Verify restored database
SELECT 
    name AS DatabaseName, 
    state_desc AS [State], 
    recovery_model_desc AS RecoveryModel,
    create_date AS Created
FROM sys.databases 
WHERE name = 'HospitalBackupDemo';
GO

-- Quick smoke test: count key tables
USE HospitalBackupDemo;
GO

SELECT 'Patients' AS TableName, COUNT(*) AS [RowCount] FROM dbo.Patients
UNION ALL
SELECT 'Appointments', COUNT(*) FROM dbo.Appointments
UNION ALL
SELECT 'Billing', COUNT(*) FROM dbo.Billing;
GO

PRINT '✓ Disaster recovery restore completed successfully.';
