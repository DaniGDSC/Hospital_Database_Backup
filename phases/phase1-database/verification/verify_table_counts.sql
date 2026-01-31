SET NOCOUNT ON;
USE HospitalBackupDemo;

SELECT 'Admissions' AS TableName, COUNT(*) AS TotalRows FROM dbo.Admissions
UNION ALL SELECT 'Appointments', COUNT(*) FROM dbo.Appointments
UNION ALL SELECT 'AuditLog', COUNT(*) FROM dbo.AuditLog
UNION ALL SELECT 'BackupHistory', COUNT(*) FROM dbo.BackupHistory
UNION ALL SELECT 'Billing', COUNT(*) FROM dbo.Billing
UNION ALL SELECT 'BillingDetails', COUNT(*) FROM dbo.BillingDetails
UNION ALL SELECT 'Departments', COUNT(*) FROM dbo.Departments
UNION ALL SELECT 'Doctors', COUNT(*) FROM dbo.Doctors
UNION ALL SELECT 'LabTests', COUNT(*) FROM dbo.LabTests
UNION ALL SELECT 'MedicalRecords', COUNT(*) FROM dbo.MedicalRecords
UNION ALL SELECT 'Nurses', COUNT(*) FROM dbo.Nurses
UNION ALL SELECT 'Patients', COUNT(*) FROM dbo.Patients
UNION ALL SELECT 'Payments', COUNT(*) FROM dbo.Payments
UNION ALL SELECT 'PrescriptionDetails', COUNT(*) FROM dbo.PrescriptionDetails
UNION ALL SELECT 'Prescriptions', COUNT(*) FROM dbo.Prescriptions
UNION ALL SELECT 'Rooms', COUNT(*) FROM dbo.Rooms
UNION ALL SELECT 'SecurityEvents', COUNT(*) FROM dbo.SecurityEvents
UNION ALL SELECT 'SystemConfiguration', COUNT(*) FROM dbo.SystemConfiguration;
