-- Bulk insert 150 sample Admissions records
USE HospitalBackupDemo;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample Admissions ===';

DECLARE @Counter INT = 1;
DECLARE @PatientID INT;
DECLARE @RoomID INT;
DECLARE @DoctorID INT;
DECLARE @DepartmentID INT;
DECLARE @AdmissionDate DATETIME2;
DECLARE @DischargeDate DATETIME2;

-- Get defaults once
DECLARE @DefaultPatientID INT = (SELECT TOP 1 PatientID FROM Patients);
DECLARE @DefaultRoomID INT = (SELECT TOP 1 RoomID FROM Rooms);
DECLARE @DefaultDoctorID INT = (SELECT TOP 1 DoctorID FROM Doctors);
DECLARE @DefaultDepartmentID INT = (SELECT TOP 1 DepartmentID FROM Departments);

WHILE @Counter <= 150
BEGIN
    SET @PatientID = ISNULL((SELECT TOP 1 PatientID FROM Patients ORDER BY NEWID()), @DefaultPatientID);
    SET @RoomID = ISNULL((SELECT TOP 1 RoomID FROM Rooms ORDER BY NEWID()), @DefaultRoomID);
    SET @DoctorID = ISNULL((SELECT TOP 1 DoctorID FROM Doctors ORDER BY NEWID()), @DefaultDoctorID);
    SET @DepartmentID = ISNULL((SELECT TOP 1 DepartmentID FROM Departments ORDER BY NEWID()), @DefaultDepartmentID);
    SET @AdmissionDate = DATEADD(DAY, -CAST(RAND()*365 AS INT), GETDATE());
    SET @DischargeDate = DATEADD(DAY, CAST(RAND()*30+1 AS INT), @AdmissionDate);
    
    INSERT INTO dbo.Admissions 
    (AdmissionNumber, PatientID, RoomID, DoctorID, DepartmentID, AdmissionDate, DischargeDate,
     AdmissionType, AdmissionReason, InitialDiagnosis, Status, RoomDailyCost, TreatmentCost)
    VALUES
    ('ADM' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     @PatientID,
     @RoomID,
     @DoctorID,
     @DepartmentID,
     @AdmissionDate,
     CASE WHEN @DischargeDate < GETDATE() THEN @DischargeDate ELSE NULL END,
     CASE WHEN @Counter % 3 = 0 THEN 'Emergency' WHEN @Counter % 3 = 1 THEN 'Elective' ELSE 'Urgent' END,
     'Admission reason ' + CAST(@Counter AS VARCHAR),
     'Diagnosis ' + CAST(@Counter AS VARCHAR),
     CASE WHEN @DischargeDate < GETDATE() THEN 'Discharged' ELSE 'Active' END,
     CAST(RAND()*500000+50000 AS DECIMAL(10,2)),
     CAST(RAND()*1000000+100000 AS DECIMAL(15,2)));
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 Admissions inserted';
GO
