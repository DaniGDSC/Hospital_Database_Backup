-- Filtered views that hide soft-deleted records
-- Category 1.1 Item 5: Soft Delete for PHI
-- All application queries should use these views instead of base tables
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '--- Creating active record views (soft delete filter) ---';

-- Active Patients
IF OBJECT_ID('dbo.vw_ActivePatients', 'V') IS NOT NULL DROP VIEW dbo.vw_ActivePatients;
GO
CREATE VIEW dbo.vw_ActivePatients AS
SELECT * FROM dbo.Patients WHERE IsDeleted = 0;
GO

-- Active MedicalRecords
IF OBJECT_ID('dbo.vw_ActiveMedicalRecords', 'V') IS NOT NULL DROP VIEW dbo.vw_ActiveMedicalRecords;
GO
CREATE VIEW dbo.vw_ActiveMedicalRecords AS
SELECT * FROM dbo.MedicalRecords WHERE IsDeleted = 0;
GO

-- Active Prescriptions
IF OBJECT_ID('dbo.vw_ActivePrescriptions', 'V') IS NOT NULL DROP VIEW dbo.vw_ActivePrescriptions;
GO
CREATE VIEW dbo.vw_ActivePrescriptions AS
SELECT * FROM dbo.Prescriptions WHERE IsDeleted = 0;
GO

-- Active PrescriptionDetails
IF OBJECT_ID('dbo.vw_ActivePrescriptionDetails', 'V') IS NOT NULL DROP VIEW dbo.vw_ActivePrescriptionDetails;
GO
CREATE VIEW dbo.vw_ActivePrescriptionDetails AS
SELECT pd.* FROM dbo.PrescriptionDetails pd
JOIN dbo.Prescriptions p ON pd.PrescriptionID = p.PrescriptionID
WHERE pd.IsDeleted = 0 AND p.IsDeleted = 0;
GO

-- Active LabTests
IF OBJECT_ID('dbo.vw_ActiveLabTests', 'V') IS NOT NULL DROP VIEW dbo.vw_ActiveLabTests;
GO
CREATE VIEW dbo.vw_ActiveLabTests AS
SELECT * FROM dbo.LabTests WHERE IsDeleted = 0;
GO

-- Active Admissions
IF OBJECT_ID('dbo.vw_ActiveAdmissions', 'V') IS NOT NULL DROP VIEW dbo.vw_ActiveAdmissions;
GO
CREATE VIEW dbo.vw_ActiveAdmissions AS
SELECT * FROM dbo.Admissions WHERE IsDeleted = 0;
GO

-- Active Appointments
IF OBJECT_ID('dbo.vw_ActiveAppointments', 'V') IS NOT NULL DROP VIEW dbo.vw_ActiveAppointments;
GO
CREATE VIEW dbo.vw_ActiveAppointments AS
SELECT * FROM dbo.Appointments WHERE IsDeleted = 0;
GO

PRINT '✓ 7 active record views created (soft delete filter)';
GO
