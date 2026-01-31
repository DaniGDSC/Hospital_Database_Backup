-- Bulk insert 150 sample Appointments records
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample Appointments ===';

DECLARE @Counter INT = 1;
DECLARE @PatientID INT;
DECLARE @DoctorID INT;
DECLARE @DepartmentID INT;
DECLARE @RoomID INT;
DECLARE @AppointmentDate DATETIME2;

WHILE @Counter <= 150
BEGIN
    SET @PatientID = (SELECT TOP 1 PatientID FROM Patients ORDER BY NEWID());
    SET @DoctorID = (SELECT TOP 1 DoctorID FROM Doctors ORDER BY NEWID());
    SET @DepartmentID = (SELECT TOP 1 DepartmentID FROM Departments ORDER BY NEWID());
    SET @RoomID = (SELECT TOP 1 RoomID FROM Rooms ORDER BY NEWID());
    SET @AppointmentDate = DATEADD(DAY, CAST(RAND()*90 AS INT), GETDATE());
    
    INSERT INTO dbo.Appointments 
    (AppointmentNumber, PatientID, DoctorID, DepartmentID, RoomID, AppointmentDate, AppointmentEndTime,
     AppointmentType, Status, ReasonForVisit, EstimatedDuration, Notes)
    VALUES
    ('APT' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     @PatientID,
     @DoctorID,
     @DepartmentID,
     @RoomID,
     @AppointmentDate,
     DATEADD(MINUTE, 30, @AppointmentDate),
     CASE WHEN RAND() > 0.7 THEN 'New Consultation' WHEN RAND() > 0.3 THEN 'Follow-up' ELSE 'General Checkup' END,
     CASE WHEN @AppointmentDate > GETDATE() THEN 'Scheduled' ELSE CASE WHEN RAND() > 0.1 THEN 'Completed' ELSE 'Cancelled' END END,
     'Regular checkup',
     30,
     'Appointment ' + CAST(@Counter AS VARCHAR));
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 Appointments inserted';
GO
