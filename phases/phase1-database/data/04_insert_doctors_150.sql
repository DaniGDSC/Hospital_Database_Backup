-- Bulk insert 150 sample Doctors records
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample Doctors ===';

DECLARE @Counter INT = 1;
DECLARE @DeptID INT;

WHILE @Counter <= 150
BEGIN
    SET @DeptID = (SELECT TOP 1 DepartmentID FROM Departments ORDER BY NEWID());
    DECLARE @SpecialtyList NVARCHAR(MAX) = 'Cardiology,Neurology,Orthopedics,Gastroenterology,Pulmonology,Nephrology,Oncology,Pediatrics,OB/GYN,Psychiatry,Dermatology,ENT,Ophthalmology,General Medicine,Surgery';
    DECLARE @Specialty NVARCHAR(100) = (SELECT SUBSTRING(@SpecialtyList, CAST(RAND()*14 AS INT)*20+1, 20));
    
    INSERT INTO dbo.Doctors 
    (EmployeeCode, FirstName, LastName, DateOfBirth, Gender, NationalID, DepartmentID, 
     Specialty, MedicalDegree, LicenseNumber, Email, Phone, MobilePhone, 
     Address, City, Country, PostalCode, HireDate, BaseSalary, ConsultationFee, IsActive)
    VALUES
    ('DOC' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     'Doctor' + CAST(@Counter AS VARCHAR),
     'Last' + CAST(@Counter AS VARCHAR),
     DATEADD(YEAR, -CAST(RAND()*30+25 AS INT), GETDATE()),
     CASE WHEN RAND() > 0.5 THEN 'M' ELSE 'F' END,
     '0' + CAST(1000000000 + @Counter AS VARCHAR),
     @DeptID,
     @Specialty,
     'MD',
     'LIC' + CAST(10000 + @Counter AS VARCHAR),
     'doctor' + CAST(@Counter AS VARCHAR) + '@hospital.test',
     '090123' + RIGHT('0000' + CAST(@Counter AS VARCHAR), 4),
     '098765' + RIGHT('0000' + CAST(@Counter AS VARCHAR), 4),
     CAST(@Counter AS VARCHAR) + ' Medical Street',
     'Hanoi',
     'Vietnam',
     '100000',
     DATEADD(YEAR, -CAST(RAND()*15 AS INT), GETDATE()),
     50000000 + (@Counter * 100000),
     500000 + (@Counter * 5000),
     1);
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 Doctors inserted';
GO
