-- Rollback: Core tables (Phase 1.2a)
-- Drops: Rooms, Patients, Nurses, Doctors, Departments (reverse FK order)
-- Must run AFTER rollback_clinical_tables.sql and rollback_billing_tables.sql
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Rollback: Core Tables ===';

-- Drop patient audit trigger first
IF OBJECT_ID('dbo.trg_Patients_Audit', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_Patients_Audit;
GO

-- Remove circular FK before dropping Departments
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Departments_HeadDoctor')
    ALTER TABLE dbo.Departments DROP CONSTRAINT FK_Departments_HeadDoctor;
GO

IF OBJECT_ID('dbo.Rooms', 'U') IS NOT NULL DROP TABLE dbo.Rooms;
IF OBJECT_ID('dbo.Patients', 'U') IS NOT NULL DROP TABLE dbo.Patients;
IF OBJECT_ID('dbo.Nurses', 'U') IS NOT NULL DROP TABLE dbo.Nurses;
IF OBJECT_ID('dbo.Doctors', 'U') IS NOT NULL DROP TABLE dbo.Doctors;
IF OBJECT_ID('dbo.Departments', 'U') IS NOT NULL DROP TABLE dbo.Departments;
GO

PRINT '✓ Core tables dropped';
GO
