-- Bulk insert 150 sample LabTests records
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample LabTests ===';

DECLARE @Counter INT = 1;
DECLARE @PatientID INT;
DECLARE @DoctorID INT;
DECLARE @OrderDate DATETIME2;

WHILE @Counter <= 150
BEGIN
    SET @PatientID = (SELECT TOP 1 PatientID FROM Patients ORDER BY NEWID());
    SET @DoctorID = (SELECT TOP 1 DoctorID FROM Doctors ORDER BY NEWID());
    SET @OrderDate = DATEADD(DAY, -CAST(RAND()*180 AS INT), GETDATE());
    
    INSERT INTO dbo.LabTests 
    (TestNumber, PatientID, DoctorID, TestCode, TestName, TestCategory, TestType,
     OrderDate, SampleCollectionDate, ResultDate, ResultValue, NormalRange, Status, Notes)
    VALUES
    ('LAB' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     @PatientID,
     @DoctorID,
     'LT' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     'Test ' + CAST(@Counter AS VARCHAR),
     CASE WHEN @Counter % 4 = 1 THEN 'Blood' WHEN @Counter % 4 = 2 THEN 'Urine' WHEN @Counter % 4 = 3 THEN 'Imaging' ELSE 'Biopsy' END,
     CASE WHEN @Counter % 3 = 0 THEN 'Routine' ELSE 'Urgent' END,
     @OrderDate,
     DATEADD(DAY, 1, @OrderDate),
     DATEADD(DAY, 5, @OrderDate),
     CAST(RAND()*100 AS VARCHAR(20)),
     '0-100',
     'Completed',
     'Lab test result ' + CAST(@Counter AS VARCHAR));
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 LabTests inserted';
GO
