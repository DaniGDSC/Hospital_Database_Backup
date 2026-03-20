-- Rollback: System tables (Phase 1.2d)
-- Drops: SystemConfiguration, SecurityEvents, BackupHistory, AuditLog
-- Also handles Phase 2/3 tables that depend on these (BackupVerificationLog, SecurityAuditEvents)
-- Run this FIRST in rollback sequence (no incoming FK dependencies)
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Rollback: System Tables ===';

-- Must temporarily disable DDL protection trigger (created by Phase 2)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
BEGIN
    DISABLE TRIGGER trg_Protect_AuditTables ON DATABASE;
    PRINT '  DDL protection trigger disabled temporarily';
END
GO

-- Log rollback to AuditLog before dropping it
IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL
BEGIN
    BEGIN TRY
        INSERT INTO dbo.AuditLog (AuditDate, TableName, RecordID, Action, ActionType, UserName, Severity, Notes)
        VALUES (SYSDATETIME(), 'SCHEMA_ROLLBACK', 0, 'DELETE', 'ROLLBACK', SUSER_SNAME(), 'Critical',
                'Rolling back system tables');
    END TRY
    BEGIN CATCH
        PRINT '  (AuditLog insert skipped: ' + ERROR_MESSAGE() + ')';
    END CATCH
END
GO

-- Drop tables in safe order (Phase 2/3 dependents first, then Phase 1 tables)
-- These may or may not exist depending on which phases ran
IF OBJECT_ID('dbo.BackupVerificationLog', 'U') IS NOT NULL DROP TABLE dbo.BackupVerificationLog;
IF OBJECT_ID('dbo.SecurityAuditEvents', 'U') IS NOT NULL DROP TABLE dbo.SecurityAuditEvents;
IF OBJECT_ID('dbo.CapacityForecast', 'U') IS NOT NULL DROP TABLE dbo.CapacityForecast;
IF OBJECT_ID('dbo.CapacityHistory', 'U') IS NOT NULL DROP TABLE dbo.CapacityHistory;
IF OBJECT_ID('dbo.SchemaVersionHistory', 'U') IS NOT NULL DROP TABLE dbo.SchemaVersionHistory;
-- Phase 1 system tables
IF OBJECT_ID('dbo.SystemConfiguration', 'U') IS NOT NULL DROP TABLE dbo.SystemConfiguration;
IF OBJECT_ID('dbo.SecurityEvents', 'U') IS NOT NULL DROP TABLE dbo.SecurityEvents;
IF OBJECT_ID('dbo.BackupHistory', 'U') IS NOT NULL DROP TABLE dbo.BackupHistory;
IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL DROP TABLE dbo.AuditLog;
GO

-- Re-enable DDL trigger if it still exists (it was on AuditLog which is now dropped,
-- but the DATABASE-level trigger itself may still exist)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
BEGIN
    BEGIN TRY
        ENABLE TRIGGER trg_Protect_AuditTables ON DATABASE;
        PRINT '  DDL protection trigger re-enabled';
    END TRY
    BEGIN CATCH
        PRINT '  (trigger re-enable skipped — tables dropped)';
    END CATCH
END
GO

PRINT '✓ System tables dropped';
GO
