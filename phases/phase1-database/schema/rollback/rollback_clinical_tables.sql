-- Rollback: Clinical tables (Phase 1.2b)
-- Drops: Admissions, LabTests, PrescriptionDetails, Prescriptions,
--         MedicalRecords, Appointments (reverse FK order)
-- Must run AFTER rollback_billing_tables.sql (Billing references Admissions/Appointments)
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Rollback: Clinical Tables ===';

-- Drop audit triggers first to avoid errors during table drops
IF OBJECT_ID('dbo.trg_LabTests_Audit', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_LabTests_Audit;
IF OBJECT_ID('dbo.trg_Prescriptions_Audit', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_Prescriptions_Audit;
IF OBJECT_ID('dbo.trg_MedicalRecords_Audit', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_MedicalRecords_Audit;
IF OBJECT_ID('dbo.trg_Appointments_Audit', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_Appointments_Audit;
GO

IF OBJECT_ID('dbo.Admissions', 'U') IS NOT NULL DROP TABLE dbo.Admissions;
IF OBJECT_ID('dbo.LabTests', 'U') IS NOT NULL DROP TABLE dbo.LabTests;
IF OBJECT_ID('dbo.PrescriptionDetails', 'U') IS NOT NULL DROP TABLE dbo.PrescriptionDetails;
IF OBJECT_ID('dbo.Prescriptions', 'U') IS NOT NULL DROP TABLE dbo.Prescriptions;
IF OBJECT_ID('dbo.MedicalRecords', 'U') IS NOT NULL DROP TABLE dbo.MedicalRecords;
IF OBJECT_ID('dbo.Appointments', 'U') IS NOT NULL DROP TABLE dbo.Appointments;
GO

PRINT '✓ Clinical tables and triggers dropped';
GO
