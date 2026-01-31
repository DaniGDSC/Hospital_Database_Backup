-- Bulk insert 150 sample PrescriptionDetails records
USE HospitalBackupDemo;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample PrescriptionDetails ===';

DECLARE @Counter INT = 1;
DECLARE @PrescriptionID INT;

WHILE @Counter <= 150
BEGIN
    SET @PrescriptionID = (SELECT TOP 1 PrescriptionID FROM Prescriptions ORDER BY NEWID());
    
    INSERT INTO dbo.PrescriptionDetails 
    (PrescriptionID, MedicationName, GenericName, MedicationType, Strength, Dosage, Route, Frequency,
     Duration, Quantity, UnitOfMeasure, UnitPrice, Instructions, SideEffects)
    VALUES
    (@PrescriptionID,
     'Medicine ' + CAST(@Counter AS VARCHAR),
     'Generic ' + CAST(@Counter AS VARCHAR),
     CASE WHEN @Counter % 4 = 0 THEN 'Tablet' WHEN @Counter % 4 = 1 THEN 'Capsule' WHEN @Counter % 4 = 2 THEN 'Syrup' ELSE 'Injection' END,
     '500mg',
     '1 tablet',
     'Oral',
     CASE WHEN RAND() > 0.7 THEN 'Once daily' WHEN RAND() > 0.3 THEN 'Twice daily' ELSE 'Three times daily' END,
     '30 days',
     CAST(RAND()*100+10 AS INT),
     'Tablets',
     CAST(RAND()*100+50 AS DECIMAL(10,2)),
     'Take with water',
     'Possible side effects: nausea, dizziness');
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 PrescriptionDetails inserted';
GO
