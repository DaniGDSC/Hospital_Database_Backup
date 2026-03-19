-- Differential backup for HospitalBackupDemo
-- Uses shared procedure created in full/01_full_backup.sql
USE master;
GO

EXEC HospitalBackupDemo.dbo.usp_PerformBackup @BackupType = 'DIFFERENTIAL';
GO
