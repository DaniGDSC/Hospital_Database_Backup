-- Bulk insert 150 sample Prescriptions records
USE HospitalBackupDemo;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample Prescriptions ===';

DECLARE @Counter INT = 1;
DECLARE @PatientID INT;
DECLARE @DoctorID INT;
DECLARE @StartDate DATETIME2;
DECLARE @EndDate DATETIME2;

WHILE @Counter <= 150
BEGIN
    SET @PatientID = (SELECT TOP 1 PatientID FROM Patients ORDER BY NEWID());
    SET @DoctorID = (SELECT TOP 1 DoctorID FROM Doctors ORDER BY NEWID());
    SET @StartDate = DATEADD(DAY, -CAST(RAND()*180 AS INT), GETDATE());
    SET @EndDate = DATEADD(DAY, 30, @StartDate);
    
    INSERT INTO dbo.Prescriptions 
    (PrescriptionNumber, RecordID, PatientID, DoctorID, PrescriptionDate, StartDate, EndDate, 
     Instructions, Status, TotalCost, Notes)
    VALUES
    ('RX' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     (SELECT TOP 1 RecordID FROM MedicalRecords ORDER BY NEWID()),
     @PatientID,
     @DoctorID,
     @StartDate,
     CAST(@StartDate AS DATE),
     CAST(@EndDate AS DATE),
     'Take as prescribed',
     CASE WHEN @EndDate > GETDATE() THEN 'Active' ELSE 'Completed' END,
     CAST(RAND()*5000+1000 AS DECIMAL(10,2)),
     'Prescription ' + CAST(@Counter AS VARCHAR));
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 Prescriptions inserted';
GO
