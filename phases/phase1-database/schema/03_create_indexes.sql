-- ==========================================================
-- Project: Database Administration & Security (INS3199)
-- File: 03_create_indexes.sql
-- Purpose: Create supporting indexes for HospitalBackupDemo
-- ==========================================================

USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating indexes for HospitalBackupDemo ===';

-- Helper template: create index only when missing to allow re-runs
-- IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = '<INDEX_NAME>' AND object_id = OBJECT_ID('<schema.table>'))
--     CREATE INDEX <INDEX_NAME> ON <schema.table> (...);

-- 1. Departments
IF OBJECT_ID('dbo.Departments', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Departments_Name' AND object_id = OBJECT_ID('dbo.Departments'))
        CREATE INDEX IX_Departments_Name ON dbo.Departments (DepartmentName);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Departments_Type' AND object_id = OBJECT_ID('dbo.Departments'))
        CREATE INDEX IX_Departments_Type ON dbo.Departments (DepartmentType, IsActive);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Departments_HeadDoctor' AND object_id = OBJECT_ID('dbo.Departments'))
        CREATE INDEX IX_Departments_HeadDoctor ON dbo.Departments (HeadDoctorID);
END
GO

-- 2. Doctors
IF OBJECT_ID('dbo.Doctors', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Doctors_Specialty' AND object_id = OBJECT_ID('dbo.Doctors'))
        CREATE INDEX IX_Doctors_Specialty ON dbo.Doctors (Specialty, SubSpecialty);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Doctors_Department' AND object_id = OBJECT_ID('dbo.Doctors'))
        CREATE INDEX IX_Doctors_Department ON dbo.Doctors (DepartmentID, IsActive);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Doctors_Email' AND object_id = OBJECT_ID('dbo.Doctors'))
        CREATE INDEX IX_Doctors_Email ON dbo.Doctors (Email);
END
GO

-- 3. Nurses
IF OBJECT_ID('dbo.Nurses', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Nurses_Department' AND object_id = OBJECT_ID('dbo.Nurses'))
        CREATE INDEX IX_Nurses_Department ON dbo.Nurses (DepartmentID, ShiftType);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Nurses_Email' AND object_id = OBJECT_ID('dbo.Nurses'))
        CREATE INDEX IX_Nurses_Email ON dbo.Nurses (Email);
END
GO

-- 4. Patients
IF OBJECT_ID('dbo.Patients', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Patients_Name' AND object_id = OBJECT_ID('dbo.Patients'))
        CREATE INDEX IX_Patients_Name ON dbo.Patients (LastName, FirstName);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Patients_Email' AND object_id = OBJECT_ID('dbo.Patients'))
        CREATE INDEX IX_Patients_Email ON dbo.Patients (Email);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Patients_Phone' AND object_id = OBJECT_ID('dbo.Patients'))
        CREATE INDEX IX_Patients_Phone ON dbo.Patients (Phone, AlternatePhone);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Patients_NationalID' AND object_id = OBJECT_ID('dbo.Patients'))
        CREATE INDEX IX_Patients_NationalID ON dbo.Patients (NationalID);
END
GO

-- 5. Rooms
IF OBJECT_ID('dbo.Rooms', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Rooms_Department' AND object_id = OBJECT_ID('dbo.Rooms'))
        CREATE INDEX IX_Rooms_Department ON dbo.Rooms (DepartmentID, RoomType);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Rooms_Status' AND object_id = OBJECT_ID('dbo.Rooms'))
        CREATE INDEX IX_Rooms_Status ON dbo.Rooms (Status, RoomNumber);
END
GO

-- 6. Appointments
IF OBJECT_ID('dbo.Appointments', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_DateStatus' AND object_id = OBJECT_ID('dbo.Appointments'))
        CREATE INDEX IX_Appointments_DateStatus ON dbo.Appointments (AppointmentDate, Status);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Patient' AND object_id = OBJECT_ID('dbo.Appointments'))
        CREATE INDEX IX_Appointments_Patient ON dbo.Appointments (PatientID, AppointmentDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Doctor' AND object_id = OBJECT_ID('dbo.Appointments'))
        CREATE INDEX IX_Appointments_Doctor ON dbo.Appointments (DoctorID, AppointmentDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Department' AND object_id = OBJECT_ID('dbo.Appointments'))
        CREATE INDEX IX_Appointments_Department ON dbo.Appointments (DepartmentID, Status);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Room' AND object_id = OBJECT_ID('dbo.Appointments'))
        CREATE INDEX IX_Appointments_Room ON dbo.Appointments (RoomID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_RescheduledFrom' AND object_id = OBJECT_ID('dbo.Appointments'))
        CREATE INDEX IX_Appointments_RescheduledFrom ON dbo.Appointments (RescheduledFrom);
END
GO

-- 7. MedicalRecords
IF OBJECT_ID('dbo.MedicalRecords', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MedicalRecords_VisitDate' AND object_id = OBJECT_ID('dbo.MedicalRecords'))
        CREATE INDEX IX_MedicalRecords_VisitDate ON dbo.MedicalRecords (VisitDate DESC);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MedicalRecords_Patient' AND object_id = OBJECT_ID('dbo.MedicalRecords'))
        CREATE INDEX IX_MedicalRecords_Patient ON dbo.MedicalRecords (PatientID, VisitDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MedicalRecords_Doctor' AND object_id = OBJECT_ID('dbo.MedicalRecords'))
        CREATE INDEX IX_MedicalRecords_Doctor ON dbo.MedicalRecords (DoctorID, VisitDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MedicalRecords_Appointment' AND object_id = OBJECT_ID('dbo.MedicalRecords'))
        CREATE INDEX IX_MedicalRecords_Appointment ON dbo.MedicalRecords (AppointmentID);
END
GO

-- 8. Prescriptions
IF OBJECT_ID('dbo.Prescriptions', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prescriptions_Record' AND object_id = OBJECT_ID('dbo.Prescriptions'))
        CREATE INDEX IX_Prescriptions_Record ON dbo.Prescriptions (RecordID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prescriptions_Patient' AND object_id = OBJECT_ID('dbo.Prescriptions'))
        CREATE INDEX IX_Prescriptions_Patient ON dbo.Prescriptions (PatientID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prescriptions_Doctor' AND object_id = OBJECT_ID('dbo.Prescriptions'))
        CREATE INDEX IX_Prescriptions_Doctor ON dbo.Prescriptions (DoctorID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prescriptions_Date' AND object_id = OBJECT_ID('dbo.Prescriptions'))
        CREATE INDEX IX_Prescriptions_Date ON dbo.Prescriptions (PrescriptionDate, Status);
END
GO

-- 9. PrescriptionDetails
IF OBJECT_ID('dbo.PrescriptionDetails', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PrescriptionDetails_Header' AND object_id = OBJECT_ID('dbo.PrescriptionDetails'))
        CREATE INDEX IX_PrescriptionDetails_Header ON dbo.PrescriptionDetails (PrescriptionID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PrescriptionDetails_Medication' AND object_id = OBJECT_ID('dbo.PrescriptionDetails'))
        CREATE INDEX IX_PrescriptionDetails_Medication ON dbo.PrescriptionDetails (MedicationName, MedicationType);
END
GO

-- 10. LabTests
IF OBJECT_ID('dbo.LabTests', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LabTests_Patient' AND object_id = OBJECT_ID('dbo.LabTests'))
        CREATE INDEX IX_LabTests_Patient ON dbo.LabTests (PatientID, TestCategory, Status);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LabTests_Doctor' AND object_id = OBJECT_ID('dbo.LabTests'))
        CREATE INDEX IX_LabTests_Doctor ON dbo.LabTests (DoctorID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LabTests_Record' AND object_id = OBJECT_ID('dbo.LabTests'))
        CREATE INDEX IX_LabTests_Record ON dbo.LabTests (RecordID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LabTests_Dates' AND object_id = OBJECT_ID('dbo.LabTests'))
        CREATE INDEX IX_LabTests_Dates ON dbo.LabTests (OrderDate, ResultDate, ReportDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LabTests_Department' AND object_id = OBJECT_ID('dbo.LabTests'))
        CREATE INDEX IX_LabTests_Department ON dbo.LabTests (DepartmentID);
END
GO

-- 11. Admissions
IF OBJECT_ID('dbo.Admissions', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_Patient' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_Patient ON dbo.Admissions (PatientID, AdmissionDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_Doctor' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_Doctor ON dbo.Admissions (DoctorID, AdmissionDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_Department' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_Department ON dbo.Admissions (DepartmentID, Status);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_Room' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_Room ON dbo.Admissions (RoomID, Status);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_DischargedBy' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_DischargedBy ON dbo.Admissions (DischargedBy);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_AttendingNurse' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_AttendingNurse ON dbo.Admissions (AttendingNurseID);
END
GO

-- 12. Billing
IF OBJECT_ID('dbo.Billing', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Patient' AND object_id = OBJECT_ID('dbo.Billing'))
        CREATE INDEX IX_Billing_Patient ON dbo.Billing (PatientID, InvoiceDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Appointment' AND object_id = OBJECT_ID('dbo.Billing'))
        CREATE INDEX IX_Billing_Appointment ON dbo.Billing (AppointmentID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Admission' AND object_id = OBJECT_ID('dbo.Billing'))
        CREATE INDEX IX_Billing_Admission ON dbo.Billing (AdmissionID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Status' AND object_id = OBJECT_ID('dbo.Billing'))
        CREATE INDEX IX_Billing_Status ON dbo.Billing (PaymentStatus, DueDate);
END
GO

-- 13. BillingDetails
IF OBJECT_ID('dbo.BillingDetails', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BillingDetails_Header' AND object_id = OBJECT_ID('dbo.BillingDetails'))
        CREATE INDEX IX_BillingDetails_Header ON dbo.BillingDetails (BillingID, LineNumber);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BillingDetails_ServiceType' AND object_id = OBJECT_ID('dbo.BillingDetails'))
        CREATE INDEX IX_BillingDetails_ServiceType ON dbo.BillingDetails (ServiceType, ServiceDate);
END
GO

-- 14. Payments
IF OBJECT_ID('dbo.Payments', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_Billing' AND object_id = OBJECT_ID('dbo.Payments'))
        CREATE INDEX IX_Payments_Billing ON dbo.Payments (BillingID, PaymentDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_Patient' AND object_id = OBJECT_ID('dbo.Payments'))
        CREATE INDEX IX_Payments_Patient ON dbo.Payments (PatientID, PaymentDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_MethodStatus' AND object_id = OBJECT_ID('dbo.Payments'))
        CREATE INDEX IX_Payments_MethodStatus ON dbo.Payments (PaymentMethod, Status);
END
GO

-- 15. AuditLog
IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLog_TableRecord' AND object_id = OBJECT_ID('dbo.AuditLog'))
        CREATE INDEX IX_AuditLog_TableRecord ON dbo.AuditLog (SchemaName, TableName, RecordID);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLog_ActionDate' AND object_id = OBJECT_ID('dbo.AuditLog'))
        CREATE INDEX IX_AuditLog_ActionDate ON dbo.AuditLog (Action, AuditDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLog_UserSeverity' AND object_id = OBJECT_ID('dbo.AuditLog'))
        CREATE INDEX IX_AuditLog_UserSeverity ON dbo.AuditLog (UserName, Severity);
END
GO

-- 16. BackupHistory
IF OBJECT_ID('dbo.BackupHistory', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BackupHistory_TypeStatus' AND object_id = OBJECT_ID('dbo.BackupHistory'))
        CREATE INDEX IX_BackupHistory_TypeStatus ON dbo.BackupHistory (BackupType, BackupStatus);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BackupHistory_Date' AND object_id = OBJECT_ID('dbo.BackupHistory'))
        CREATE INDEX IX_BackupHistory_Date ON dbo.BackupHistory (BackupStartDate, BackupEndDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BackupHistory_Base' AND object_id = OBJECT_ID('dbo.BackupHistory'))
        CREATE INDEX IX_BackupHistory_Base ON dbo.BackupHistory (FullBackupBaseID);
END
GO

-- 17. SecurityEvents
IF OBJECT_ID('dbo.SecurityEvents', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SecurityEvents_TypeSeverity' AND object_id = OBJECT_ID('dbo.SecurityEvents'))
        CREATE INDEX IX_SecurityEvents_TypeSeverity ON dbo.SecurityEvents (EventType, Severity);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SecurityEvents_Date' AND object_id = OBJECT_ID('dbo.SecurityEvents'))
        CREATE INDEX IX_SecurityEvents_Date ON dbo.SecurityEvents (EventDate);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SecurityEvents_Login' AND object_id = OBJECT_ID('dbo.SecurityEvents'))
        CREATE INDEX IX_SecurityEvents_Login ON dbo.SecurityEvents (LoginName, SourceIP);
END
GO

-- 18. SystemConfiguration
IF OBJECT_ID('dbo.SystemConfiguration', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SystemConfiguration_Category' AND object_id = OBJECT_ID('dbo.SystemConfiguration'))
        CREATE INDEX IX_SystemConfiguration_Category ON dbo.SystemConfiguration (ConfigCategory, IsActive);
END
GO

-- Additional indexes identified during review
-- Admissions: DischargeDate range queries
IF OBJECT_ID('dbo.Admissions', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_DischargeDate' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_DischargeDate ON dbo.Admissions (DischargeDate) INCLUDE (PatientID, Status);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_Status' AND object_id = OBJECT_ID('dbo.Admissions'))
        CREATE INDEX IX_Admissions_Status ON dbo.Admissions (Status) INCLUDE (PatientID, AdmissionDate);
END
GO

-- Billing: PaymentStatus analytics
IF OBJECT_ID('dbo.Billing', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_PaymentStatus' AND object_id = OBJECT_ID('dbo.Billing'))
        CREATE INDEX IX_Billing_PaymentStatus ON dbo.Billing (PaymentStatus) INCLUDE (PatientID, TotalAmount, Balance);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_DueDate' AND object_id = OBJECT_ID('dbo.Billing'))
        CREATE INDEX IX_Billing_DueDate ON dbo.Billing (PaymentDueDate) WHERE PaymentStatus IN ('Pending', 'Partial', 'Overdue');
END
GO

-- MedicalRecords: Diagnosis searches
IF OBJECT_ID('dbo.MedicalRecords', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MedicalRecords_DiagnosisCode' AND object_id = OBJECT_ID('dbo.MedicalRecords'))
        CREATE INDEX IX_MedicalRecords_DiagnosisCode ON dbo.MedicalRecords (DiagnosisCode) INCLUDE (PatientID, DoctorID, VisitDate);
END
GO

PRINT '✓ Index creation completed.';
GO

-- Verify created indexes
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_unique AS IsUnique
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE t.is_ms_shipped = 0
ORDER BY t.name, i.name;
GO
