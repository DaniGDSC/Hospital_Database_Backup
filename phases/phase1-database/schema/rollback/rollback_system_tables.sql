-- Rollback: System tables (Phase 1.2d)
-- Drops: SystemConfiguration, SecurityEvents, BackupHistory, AuditLog
-- Run this FIRST in rollback sequence (no incoming FK dependencies)
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Rollback: System Tables ===';

-- Must temporarily disable DDL protection trigger
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
BEGIN
    DISABLE TRIGGER trg_Protect_AuditTables ON DATABASE;
    PRINT '  DDL protection trigger disabled temporarily';
END
GO

-- Log rollback to AuditLog before dropping it
IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL
BEGIN
    INSERT INTO dbo.AuditLog (AuditDate, TableName, RecordID, Action, ActionType, UserName, Severity, Notes)
    VALUES (SYSDATETIME(), 'SCHEMA_ROLLBACK', 0, 'DELETE', 'ROLLBACK', SUSER_SNAME(), 'Critical',
            'Rolling back system tables: SystemConfiguration, SecurityEvents, BackupHistory, BackupVerificationLog, AuditLog');
END
GO

IF OBJECT_ID('dbo.SystemConfiguration', 'U') IS NOT NULL DROP TABLE dbo.SystemConfiguration;
IF OBJECT_ID('dbo.BackupVerificationLog', 'U') IS NOT NULL DROP TABLE dbo.BackupVerificationLog;
IF OBJECT_ID('dbo.SecurityEvents', 'U') IS NOT NULL DROP TABLE dbo.SecurityEvents;
IF OBJECT_ID('dbo.BackupHistory', 'U') IS NOT NULL DROP TABLE dbo.BackupHistory;
IF OBJECT_ID('dbo.SecurityAuditEvents', 'U') IS NOT NULL DROP TABLE dbo.SecurityAuditEvents;
IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL DROP TABLE dbo.AuditLog;
GO

PRINT '✓ System tables dropped';
GO
