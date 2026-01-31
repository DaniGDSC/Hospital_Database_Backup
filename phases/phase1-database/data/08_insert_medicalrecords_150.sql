-- Bulk insert 150 sample MedicalRecords records
USE HospitalBackupDemo;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample MedicalRecords ===';

DECLARE @Counter INT = 1;
DECLARE @PatientID INT;
DECLARE @DoctorID INT;
DECLARE @RecordDate DATETIME2;

WHILE @Counter <= 150
BEGIN
    SET @PatientID = (SELECT TOP 1 PatientID FROM Patients ORDER BY NEWID());
    SET @DoctorID = (SELECT TOP 1 DoctorID FROM Doctors ORDER BY NEWID());
    SET @RecordDate = DATEADD(DAY, -CAST(RAND()*365 AS INT), GETDATE());
    
    INSERT INTO dbo.MedicalRecords 
    (RecordNumber, PatientID, DoctorID, VisitDate, VisitType, ChiefComplaint, PresentIllness, 
     Diagnosis, TreatmentPlan, FollowUpInstructions, Notes)
    VALUES
    ('REC' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     @PatientID,
     @DoctorID,
     @RecordDate,
     CASE WHEN @Counter % 4 = 1 THEN 'Outpatient' WHEN @Counter % 4 = 2 THEN 'Emergency' WHEN @Counter % 4 = 3 THEN 'Inpatient' ELSE 'Follow-up' END,
     'Chief complaint record ' + CAST(@Counter AS VARCHAR),
     'Patient present illness ' + CAST(@Counter AS VARCHAR),
     'Diagnosis record ' + CAST(@Counter AS VARCHAR),
     'Treatment plan ' + CAST(@Counter AS VARCHAR),
     'Follow-up in 1 week',
     'Medical record notes ' + CAST(@Counter AS VARCHAR));
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 MedicalRecords inserted';
GO
