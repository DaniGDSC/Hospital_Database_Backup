-- Weekly operational report snapshot
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Weekly report: activity summary ===';

-- Appointment volume last 7 days
SELECT 'AppointmentsLast7Days' AS Metric, COUNT(*) AS Value
FROM dbo.Appointments
WHERE AppointmentDate >= DATEADD(DAY, -7, SYSDATETIME());

-- Admissions last 7 days
SELECT 'AdmissionsLast7Days' AS Metric, COUNT(*) AS Value
FROM dbo.Admissions
WHERE AdmissionDate >= DATEADD(DAY, -7, SYSDATETIME());

-- Billing collected last 7 days
SELECT 'BillingCollectedLast7Days' AS Metric, COALESCE(SUM(AmountPaid), 0) AS Value
FROM dbo.Billing
WHERE InvoiceDate >= DATEADD(DAY, -7, SYSDATETIME());

-- Failed logins last 7 days (placeholder if you log to SecurityEvents)
SELECT 'FailedLoginsLast7Days' AS Metric, COUNT(*) AS Value
FROM dbo.SecurityEvents
WHERE EventType = 'Login Failed' AND EventDate >= DATEADD(DAY, -7, SYSDATETIME());

PRINT '✓ Weekly report completed.';
GO
