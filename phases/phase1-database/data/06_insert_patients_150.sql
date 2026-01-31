-- Bulk insert 150 sample Patients records
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample Patients ===';

DECLARE @Counter INT = 1;
DECLARE @BloodTypes TABLE (BType CHAR(3));
INSERT INTO @BloodTypes
VALUES ('A+'), ('A-'), ('B+'), ('B-'), ('AB+'), ('AB-'), ('O+'), ('O-');

DECLARE @BloodType CHAR(3);

WHILE @Counter <= 150
BEGIN
    SET @BloodType = (SELECT TOP 1 BType FROM @BloodTypes ORDER BY NEWID());
    
    INSERT INTO dbo.Patients 
    (PatientCode, FirstName, LastName, DateOfBirth, Gender, NationalID, Phone, Email,
     Address, City, Country, PostalCode, EmergencyContactName, EmergencyContactPhone,
     BloodType, InsuranceNumber, IsActive)
    VALUES
    ('PAT' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     'Patient' + CAST(@Counter AS VARCHAR),
     'Last' + CAST(@Counter AS VARCHAR),
     DATEADD(YEAR, -CAST(RAND()*70+5 AS INT), GETDATE()),
     CASE WHEN RAND() > 0.5 THEN 'M' ELSE 'F' END,
     '2' + CAST(1000000000 + @Counter AS VARCHAR),
     '092345' + RIGHT('0000' + CAST(@Counter AS VARCHAR), 4),
     'patient' + CAST(@Counter AS VARCHAR) + '@gmail.com',
     CAST(@Counter AS VARCHAR) + ' Patient Street',
     CASE WHEN @Counter % 3 = 0 THEN 'Hanoi' WHEN @Counter % 3 = 1 THEN 'HCMC' ELSE 'Da Nang' END,
     'Vietnam',
     '100000',
     'Contact' + CAST(@Counter AS VARCHAR),
     '093456' + RIGHT('0000' + CAST(@Counter AS VARCHAR), 4),
     @BloodType,
     'INS' + CAST(100000 + @Counter AS VARCHAR),
     1);
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 Patients inserted';
GO
