-- Views for HospitalBackupDemo
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating views ===';

-- Appointment summary view
IF OBJECT_ID('dbo.vAppointmentSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vAppointmentSummary;
GO
CREATE VIEW dbo.vAppointmentSummary
AS
SELECT
    a.AppointmentID,
    a.AppointmentNumber,
    a.AppointmentDate,
    a.Status,
    a.AppointmentType,
    p.PatientCode,
    p.FullName AS PatientName,
    d.FullName AS DoctorName,
    dep.DepartmentName,
    a.RoomID,
    a.Priority,
    a.ConsultationFee,
    a.IsPaid
FROM dbo.Appointments a
INNER JOIN dbo.Patients p ON a.PatientID = p.PatientID
INNER JOIN dbo.Doctors d ON a.DoctorID = d.DoctorID
INNER JOIN dbo.Departments dep ON a.DepartmentID = dep.DepartmentID;
GO

-- Billing summary view
IF OBJECT_ID('dbo.vBillingSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vBillingSummary;
GO
CREATE VIEW dbo.vBillingSummary
AS
SELECT
    b.BillingID,
    b.InvoiceNumber,
    b.PatientID,
    p.PatientCode,
    p.FullName AS PatientName,
    b.BillingType,
    b.InvoiceDate,
    b.PaymentStatus,
    b.SubTotal,
    b.TaxAmount,
    b.Discount,
    b.AdjustmentAmount,
    b.AmountPaid,
    b.Balance,
    b.Currency
FROM dbo.Billing b
INNER JOIN dbo.Patients p ON b.PatientID = p.PatientID;
GO

PRINT '✓ Views created.';
GO
