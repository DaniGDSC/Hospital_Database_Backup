-- Performance baseline: key query with STATISTICS IO/TIME
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Performance baseline: appointments search ===';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Sample workload: recent appointments by doctor/date
SELECT TOP 500
    a.AppointmentID,
    a.AppointmentDate,
    a.Status,
    p.FullName AS PatientName,
    d.FullName AS DoctorName,
    dep.DepartmentName
FROM dbo.Appointments a
JOIN dbo.Patients p ON a.PatientID = p.PatientID
JOIN dbo.Doctors d ON a.DoctorID = d.DoctorID
JOIN dbo.Departments dep ON a.DepartmentID = dep.DepartmentID
WHERE a.AppointmentDate >= DATEADD(DAY, -30, SYSDATETIME())
ORDER BY a.AppointmentDate DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

PRINT '✓ Performance baseline captured.';
GO
