-- Stored procedures for HospitalBackupDemo
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating stored procedures ===';

-- Upcoming appointments within a date range
IF OBJECT_ID('dbo.usp_GetUpcomingAppointments', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetUpcomingAppointments;
GO
CREATE PROCEDURE dbo.usp_GetUpcomingAppointments
    @StartDate DATETIME2,
    @EndDate   DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

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
        a.ReasonForVisit,
        a.RoomID
    FROM dbo.Appointments a
    INNER JOIN dbo.Patients p ON a.PatientID = p.PatientID
    INNER JOIN dbo.Doctors d ON a.DoctorID = d.DoctorID
    INNER JOIN dbo.Departments dep ON a.DepartmentID = dep.DepartmentID
    WHERE a.AppointmentDate BETWEEN @StartDate AND @EndDate
    ORDER BY a.AppointmentDate;
END
GO

-- Patient balance summary
IF OBJECT_ID('dbo.usp_GetPatientBalance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetPatientBalance;
GO
CREATE PROCEDURE dbo.usp_GetPatientBalance
    @PatientID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.BillingID,
        b.InvoiceNumber,
        b.BillingType,
        b.InvoiceDate,
        b.PaymentStatus,
        b.SubTotal,
        b.TaxAmount,
        b.Discount,
        b.AdjustmentAmount,
        b.AmountPaid,
        b.Balance
    FROM dbo.Billing b
    WHERE b.PatientID = @PatientID
    ORDER BY b.InvoiceDate DESC;
END
GO

PRINT '✓ Stored procedures created.';
GO
